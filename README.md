# Mongo Driver for Fluent

![Swift](http://img.shields.io/badge/swift-3.1-brightgreen.svg)
[![Slack Status](http://vapor.team/badge.svg)](http://vapor.team)

## Install the MongoDB server

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

## Run the MongoDB server

```shell
mongod
```

## Connecting to MongoDB with Fluent

Creating a driver is done using the [MongoDB Connection String URI Format](https://docs.mongodb.com/manual/reference/connection-string/). Initializing a `MongoDriver` such a URI will attempt a connection to MongoDB.

```
import MongoDriver
import Fluent

let driver = try MongoDriver("mongodb://localhost")
let db = Fluent.Database(driver)
```
