import Foundation

let sheetQueue = DispatchQueue(label: "sheetQueue")
private let authorizeUrl = "https://oauth.vk.com/authorize?"

final class LegacyWebPresenter {
    private let semaphore = DispatchSemaphore(value: 0)
    private var controller: LegacyWebController!
    private var fails = 0
    private var error: SessionError?
    private weak static var currentController: LegacyWebController?

    class func start(withUrl url: String) -> SessionError? {

        VK.Log.put("LegacyWebPresenter", "start")
        let presenter = LegacyWebPresenter()

        guard let controller = LegacyWebController.create(withDelegate: presenter) else {
            return SessionError.nilParentView
        }
        
        currentController = controller
        presenter.controller = controller
        presenter.controller.load(url: url)
        presenter.semaphore.wait()
        VK.Log.put("LegacyWebPresenter", "finish")

        return presenter.error
    }

    class func cancel() {
        VK.Log.put("LegacyWebPresenter", "cancel")
        currentController?.hide()
    }

    func handle(response: String) {

        if response.contains("access_token=") {
            controller.hide()
            _ = LegacyToken(fromResponse: response)
            error = nil
        }
        else if response.contains("success=1") {
            controller.hide()
            error = nil
        }
        else if response.contains("access_denied") || response.contains("cancel=1") {
            controller.hide()
            error = SessionError.deniedFromUser
        }
        else if response.contains("fail=1") {
            controller.hide()
            error = .failedAuthorization
        }
        else if response.contains(authorizeUrl) ||
            response.contains("act=security_check") ||
            response.contains("api_validation_test") ||
            response.contains("https://m.vk.com/login?") {
            controller.expand()
        }
        else {
            controller.goBack()
        }
    }

    func handle(error: SessionError) {
        VK.Log.put("LegacyWebPresenter", "handle \(error)")

        if fails <= 3 {
            self.error = error
            fails += 1
            controller.load(url: "")
        }
        else {
            controller.hide()
        }
    }

    func finish() {
        semaphore.signal()
    }
}