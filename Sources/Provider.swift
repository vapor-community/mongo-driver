import URI
import Vapor
import Fluent
import MongoKitten

public final class Provider: Vapor.Provider {
    public let provided: Providable


    public enum Error: Swift.Error {
        case noMongoDBConfig
        case missingConfig(String)
    }

    /**
        MongoDB driver created by the provider.
    */
    public let driver: MongoDriver

    public convenience init(config: Config) throws {
        guard let mongo = config["mongodb"]?.object else {
            throw Error.noMongoDBConfig
        }

        guard let host = mongo["host"]?.string else {
            throw Error.missingConfig("host")
        }

        guard let user = mongo["user"]?.string else {
            throw Error.missingConfig("user")
        }

        guard let password = mongo["password"]?.string else {
            throw Error.missingConfig("password")
        }

        guard let database = mongo["database"]?.string else {
            throw Error.missingConfig("database")
        }

        guard let port = mongo["port"]?.int else {
            throw Error.missingConfig("port")
        }

        try self.init(
            user: user,
            password: password,
            database: database,
            host: host,
            port: port
        )
    }

    public init(
        user: String,
        password: String,
        database: String,
        host: String,
        port: Int
    ) throws {
        let driver = try MongoDriver(
            database: database,
            user: user,
            password: password,
            host: host,
            port: port
        )

        self.driver = driver

        let db = Database(driver)
        Database.default = db
        provided = Providable(database: db)
    }

    /**
        Called after the Droplet has completed
        initialization and all provided items
        have been accepted.
    */
    public func afterInit(_ drop: Droplet) {

    }

    /**
        Called before the Droplet begins serving
        which is @noreturn.
    */
    public func beforeRun(_ drop: Droplet) {

    }
}
