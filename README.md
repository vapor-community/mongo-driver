# Mongo Driver for Fluent

![Swift](http://img.shields.io/badge/swift-3.0-brightgreen.svg)
[![Build Status](https://travis-ci.org/vapor/core.svg?branch=master)](https://travis-ci.org/vapor/core)
[![CircleCI](https://circleci.com/gh/vapor/core.svg?style=shield)](https://circleci.com/gh/vapor/core)
[![Code Coverage](https://codecov.io/gh/vapor/core/branch/master/graph/badge.svg)](https://codecov.io/gh/vapor/core)
[![Codebeat](https://codebeat.co/badges/a793ad97-47e3-40d9-82cf-2aafc516ef4e)](https://codebeat.co/projects/github-com-vapor-core)
[![Slack Status](http://vapor.team/badge.svg)](http://vapor.team)

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

