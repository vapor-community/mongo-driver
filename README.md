# Mongo Driver for Fluent

## Install Mongo

### OS X

```shell
brew install mongo
```

### Linux

```shell
sudo apt-get update
sudo apt-get install mongo
```

## Run

```shell
mongod
```

## Use in Vapor

When setting up your droplet, create a database using a MongoDriver instance and pass it into the Droplet intializer.

```
let mongo = try! MongoDriver(
	database: "test",
	user: "user1",
	password: "pswd1",
	host: "localhost",
	port: 27017
)
let db = Database(mongo)
let drop = Droplet(database: db)
```
