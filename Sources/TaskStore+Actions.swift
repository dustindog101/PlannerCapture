import Foundation

extension TaskStore {
    func addTask(
        title: String,
        notes: String = "",
        priority: Int = 2,
        isStarred: Bool = false,
        status: TaskStatus? = nil,
        source: String = "menubar",
        groupId: String? = nil,
        sourceRef: String? = nil
    ) {
        let resolvedStatus = status ?? SettingsStore.shared.settings.defaultStatus
        let resolvedGroup = groupId ?? SettingsStore.shared.settings.defaultGroupId
        client.createTask(
            title: title,
            notes: notes,
            status: resolvedStatus,
            priority: priority,
            isStarred: isStarred,
            source: source,
            groupId: resolvedGroup,
            sourceRef: sourceRef
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let created):
                    self.lastSeenSeq = max(self.lastSeenSeq, created.latestSeq)
                    self.markHealthyConnection()
                    self.applyServerTaskUpdate(created.task)

                    if SettingsStore.shared.settings.mirrorCLI {
                        let cliText = notes.isEmpty ? title : "\(title) :: \(notes)"
                        CLIWrapper.shared.addTask(cliText)
                    }
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        }
    }

    func removeTask(id: String) {
        guard beginAction(taskId: id, action: "archive") else { return }
        PlannerLogger.shared.log(.info, "Task action started", metadata: ["action": "archive", "task_id": id, "endpoint": "/v1/tasks/\(id)/archive"])
        client.archiveTask(taskId: id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.endAction(taskId: id)
                switch result {
                case .success(let out):
                    PlannerLogger.shared.log(.info, "Task action success", metadata: [
                        "action": "archive",
                        "task_id": id,
                        "status": out.task.status.rawValue
                    ])
                    self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                    self.markHealthyConnection()
                    self.applyServerTaskUpdate(out.task)
                case .failure(let error):
                    PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                        "action": "archive",
                        "task_id": id,
                        "error": self.describe(error)
                    ])
                    self.handleActionError(taskId: id, error: error)
                }
            }
        }
    }

    func toggleTask(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        guard beginAction(taskId: id, action: "toggle") else { return }
        let targetStatus: TaskStatus = task.status == .done ? .todo : .done
        PlannerLogger.shared.log(.info, "Task action started", metadata: [
            "action": "toggle",
            "task_id": id,
            "from_status": task.status.rawValue,
            "to_status": targetStatus.rawValue,
            "endpoint": task.status == .done ? "/v1/tasks/\(id)" : "/v1/tasks/\(id)/complete"
        ])
        if task.status == .done {
            client.patchTask(taskId: id, fields: ["status": TaskStatus.todo.rawValue]) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.endAction(taskId: id)
                    switch result {
                    case .success(let out):
                        self.logStatusTransition(taskId: id, oldStatus: task.status, newStatus: out.task.status)
                        PlannerLogger.shared.log(.info, "Task action success", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "status": out.task.status.rawValue
                        ])
                        self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                        self.markHealthyConnection()
                        self.applyServerTaskUpdate(out.task)
                    case .failure(let error):
                        PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "error": self.describe(error)
                        ])
                        self.handleActionError(taskId: id, error: error)
                    }
                }
            }
        } else {
            client.completeTask(taskId: id) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.endAction(taskId: id)
                    switch result {
                    case .success(let out):
                        self.logStatusTransition(taskId: id, oldStatus: task.status, newStatus: out.task.status)
                        PlannerLogger.shared.log(.info, "Task action success", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "status": out.task.status.rawValue
                        ])
                        self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                        self.markHealthyConnection()
                        self.applyServerTaskUpdate(out.task)
                    case .failure(let error):
                        PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                            "action": "toggle",
                            "task_id": id,
                            "error": self.describe(error)
                        ])
                        self.handleActionError(taskId: id, error: error)
                    }
                }
            }
        }
    }

    func saveTaskEdits(taskId: String, draft: TaskEditDraft, completion: @escaping (Result<Void, GatewayError>) -> Void) {
        guard beginAction(taskId: taskId, action: "edit") else {
            completion(.failure(.transport("task action already in flight")))
            return
        }
        PlannerLogger.shared.log(.info, "Task action started", metadata: [
            "action": "edit",
            "task_id": taskId,
            "endpoint": "/v1/tasks/\(taskId)"
        ])
        client.patchTask(taskId: taskId, fields: draft.patchFields()) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.endAction(taskId: taskId)
                switch result {
                case .success(let out):
                    self.logStatusTransition(taskId: taskId, oldStatus: self.task(id: taskId)?.status ?? out.task.status, newStatus: out.task.status)
                    PlannerLogger.shared.log(.info, "Task action success", metadata: [
                        "action": "edit",
                        "task_id": taskId,
                        "status": out.task.status.rawValue
                    ])
                    self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                    self.markHealthyConnection()
                    self.applyServerTaskUpdate(out.task)
                    completion(.success(()))
                case .failure(let error):
                    PlannerLogger.shared.log(.error, "Task action failed", metadata: [
                        "action": "edit",
                        "task_id": taskId,
                        "error": self.describe(error)
                    ])
                    self.handleActionError(taskId: taskId, error: error)
                    completion(.failure(error))
                }
            }
        }
    }

    func toggleStar(taskId: String, completion: ((Result<Bool, GatewayError>) -> Void)? = nil) {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return }
        guard beginAction(taskId: taskId, action: "toggle_star") else {
            completion?(.failure(.transport("task action already in flight")))
            return
        }
        let oldValue = task.isStarred
        let newValue = !oldValue
        updateLocalStar(taskId: taskId, isStarred: newValue)
        PlannerLogger.shared.log(.info, "Task action started", metadata: [
            "action": "toggle_star",
            "task_id": taskId,
            "from": "\(oldValue)",
            "to": "\(newValue)",
            "endpoint": "/v1/tasks/\(taskId)"
        ])
        client.patchTask(taskId: taskId, fields: ["is_starred": newValue ? 1 : 0]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.endAction(taskId: taskId)
                switch result {
                case .success(let out):
                    self.lastSeenSeq = max(self.lastSeenSeq, out.latestSeq)
                    self.markHealthyConnection()
                    self.applyServerTaskUpdate(out.task)
                    completion?(.success(out.task.isStarred))
                case .failure(let error):
                    self.updateLocalStar(taskId: taskId, isStarred: oldValue)
                    self.handleActionError(taskId: taskId, error: error)
                    completion?(.failure(error))
                }
            }
        }
    }

    func isTaskInFlight(_ taskId: String) -> Bool {
        inFlightActions[taskId] != nil
    }

    func createGroup(name: String, color: String = "blue", completion: @escaping (Result<Void, GatewayError>) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.decode("group name cannot be empty")))
            return
        }
        client.createGroup(name: trimmed, color: color, sortOrder: groups.count) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let out):
                    if let seq = out.latestSeq {
                        self.lastSeenSeq = max(self.lastSeenSeq, seq)
                    }
                    self.markHealthyConnection()
                    self.loadTasks()
                    completion(.success(()))
                case .failure(let error):
                    self.handle(error: error)
                    completion(.failure(error))
                }
            }
        }
    }

    func removeGroup(groupId: String, completion: @escaping (Result<Void, GatewayError>) -> Void) {
        client.archiveGroup(groupId: groupId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let out):
                    if let seq = out.latestSeq {
                        self.lastSeenSeq = max(self.lastSeenSeq, seq)
                    }
                    self.markHealthyConnection()
                    self.loadTasks()
                    completion(.success(()))
                case .failure(let error):
                    self.handle(error: error)
                    completion(.failure(error))
                }
            }
        }
    }

    func renameGroup(groupId: String, name: String, completion: @escaping (Result<Void, GatewayError>) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.decode("group name cannot be empty")))
            return
        }
        client.patchGroup(groupId: groupId, fields: ["name": trimmed]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let out):
                    if let seq = out.latestSeq {
                        self.lastSeenSeq = max(self.lastSeenSeq, seq)
                    }
                    self.markHealthyConnection()
                    self.loadTasks()
                    completion(.success(()))
                case .failure(let error):
                    self.handle(error: error)
                    completion(.failure(error))
                }
            }
        }
    }

    func beginAction(taskId: String, action: String) -> Bool {
        if inFlightActions[taskId] != nil {
            PlannerLogger.shared.log(.warn, "Ignored action on in-flight task", metadata: ["task_id": taskId, "action": action])
            return false
        }
        inFlightActions[taskId] = action
        return true
    }

    func endAction(taskId: String) {
        inFlightActions.removeValue(forKey: taskId)
    }

    func updateLocalStar(taskId: String, isStarred: Bool) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].isStarred = isStarred
        sections = buildSections(from: tasks)
    }

    func applyServerTaskUpdate(_ task: PlannerTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        } else {
            tasks.append(task)
        }
        sections = buildSections(from: tasks)
    }

    func logStatusTransition(taskId: String, oldStatus: TaskStatus, newStatus: TaskStatus) {
        guard oldStatus != newStatus else { return }
        PlannerLogger.shared.log(.info, "Task status transition", metadata: [
            "task_id": taskId,
            "from_status": oldStatus.rawValue,
            "to_status": newStatus.rawValue
        ])
    }

    func handleActionError(taskId: String, error: GatewayError) {
        if case let .http(status, _, _) = error, status == 404 {
            PlannerLogger.shared.log(.warn, "Action hit stale task; forcing refresh", metadata: ["task_id": taskId, "status": "404"])
            tasks.removeAll { $0.id == taskId }
            sections = buildSections(from: tasks)
            refreshNow()
            lastError = ""
            return
        }
        handle(error: error)
    }
}
