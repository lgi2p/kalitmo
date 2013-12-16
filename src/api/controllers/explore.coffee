
Engine = require '../../lib/engine'

engine = new Engine()

exports.explore = (req, res) ->
	type = req.params.type
	format = req.params.format
	if req.params.format not in ['data', 'stats']
		format = 'json'

	console.time "time"

	engine.all {type: req.params.type, query: req.query}, (err, results) ->
		if err
			return res.send {error: err}
		
		results.format = format

		if format is 'data'
			res.render 'explore', results
		else if format is 'stats'
			res.render 'stats.html', results
		else
			res.json results
		console.timeEnd "time"


exports.describes = (req, res) ->
	engine.describes (err, data) ->
		if err
			return res.send {error: err}
		res.send data

