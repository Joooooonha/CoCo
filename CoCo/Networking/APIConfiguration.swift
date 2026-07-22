import Foundation

enum APIConfiguration {
    static var baseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "COCO_API_BASE_URL") as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("COCO_API_BASE_URL is missing or invalid")
        }

        return url
    }
}
