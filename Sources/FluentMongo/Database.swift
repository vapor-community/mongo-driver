import Async
import Service
import MongoKitten
import Fluent

public final class MongoDB: Fluent.Database {
    public typealias Connection = MongoKitten.DatabaseConnection

    /// The database to select
    let database: String
    
    public init(database: String) {
        self.database = database
    }
    
    public func makeConnection(from config: MongoKitten.ClientSettings, on worker: Worker) -> Future<MongoKitten.DatabaseConnection> {
        do {
            return try MongoKitten.DatabaseConnection.connect(
                host: config.hosts.first ?? "localhost:27017",
                credentials: config.credentials,
                ssl: config.ssl,
                worker: worker
            )
        } catch {
            return Future(error: error)
        }
    }
}

