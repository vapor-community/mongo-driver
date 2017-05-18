# Mongo Driver for Fluent

![Swift](http://img.shields.io/badge/swift-3.1-brightgreen.svg)
[![Slack Status](http://vapor.team/badge.svg)](http://vapor.team)

## Install Mongo

For more instructions, check out https://docs.mongodb.com/master/administration/install-community/.

### OS X

```shell
brew install mongodb
```

### Ubuntu

```shell
sudo apt-get update
sudo apt-get install mongodb
```

## Run

```shell
mongod
```

## Use in Vapor

When setting up your droplet, create a database using a MongoDriver instance and pass it into the Droplet intializer.

```
let mongo = try MongoDriver(
	database: "test",
	user: "user1",
	password: "pswd1",
	host: "localhost",
	port: 27017
)
let db = Database(mongo)
let drop = Droplet(database: db)
```

