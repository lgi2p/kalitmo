
async = require 'async'
_ = require 'underscore'
_.str = require 'underscore.string'
Engine = require '../../lib/engine'

engine = new Engine()


exports.find = (req, res) ->
	# if we pass an id, we want to findOne the document of the id
	if req.query.uri?
		engine.findOne req.query.uri, (err, data) ->
			if err
				return res.send {error: err}
			res.send {uri: req.query.uri, results: data}
	else # else we want all document that match the query
		type = req.params.type
		engine.find {type: type, query: req.query}, (err, data) ->
			if err
				return res.send {error: err}
			doc = {
				query: req.query
				results: data
				type: type
				schema: engine.schema[_.str.classify type]
			}
			engine.count {type: type, query: req.query}, (err, dataCount) ->
				if err
					return res.send {error: err}
				doc.total = dataCount
				res.json(doc)


exports.facets = (req, res) ->
	if req.query.uri
		return res.send {results: []}
	engine.facets {type: req.params.type, facet: req.params.facet, query: req.query}, (err, data) ->
		if err
			res.send {error: err}
		res.send {results: data}


exports.describes = (req, res) ->
	engine.describes {type: req.params.type}, (err, data) ->
		if err
			res.send {error: err}
		res.send {structure: data}


exports.count = (req, res) ->
	if req.query.uri
		return res.send {results: 1}
	engine.count {type: req.params.type, query: req.query}, (err, data) ->
		if err
			res.send {error: err}
		res.send {results: data}


exports.describeQuery = (req, res) ->
	engine.describeQuery {type: req.params.type, query: req.query}, (err, data) ->
		if err
			res.send {error: err}
		res.send {results: data}


exports.findOne = (req, res) ->
	engine.findOne req.query.id, (err, data) ->
		if err
			res.send {error: err}
		res.send {results: data}


exports.all = (req, res) ->
	type = req.params.type
	# console.time "time"
	engine.all {type: req.params.type, query: req.query}, (err, data) ->
		if err
			res.send {error: err}
		# console.timeEnd "time"
		res.send data