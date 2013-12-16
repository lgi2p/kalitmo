
# imports 
express = require 'express'

# relative import 
api = require("./api/controllers/api")
explore = require("./api/controllers/explore")

# vars 
app = express()

# middlewares 
app.use("/public", express.static("#{__dirname}/../public"))
# app.use(express.bodyParser())
app.use(express.urlencoded())
app.use(express.json())

app.get		'/api/facets/:facet', 		api.facets
app.get		'/api/facets',		 		api.facets
app.get		'/api/describes',			api.describes
app.get 	'/api/documents', 			api.find
app.get 	'/api/query', 				api.describeQuery
app.get 	'/api/count', 				api.count
app.get		'/api/:type/describes',		api.describes
app.get		'/api/:type/facets/:facet', api.facets
app.get		'/api/:type/facets',		api.facets
app.get 	'/api/:type/documents/:id',	api.findOne
app.get 	'/api/:type/documents', 	api.find
app.get 	'/api/:type/query',	 		api.describeQuery
app.get 	'/api/:type/count',	 		api.count
app.get 	'/api/:type',	 			api.all

# view
# app.get		'/',						explore.index
app.get 	'/explore/:format/:type',	explore.explore
app.get 	'/explore',					explore.describes

module.exports = app

if require.main is module
	app.listen(4000)
