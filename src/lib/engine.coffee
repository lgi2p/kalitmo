
sparql = require 'sparql'
dbconf = require '../../config.json'
_ = require 'underscore'
_.str = require 'underscore.string'
async = require 'async'
assert = require 'assert'

querystring = require 'querystring'
request = require 'request'


class SparqlClient
    constructor: (@endpointUri)->

    query: (query, callback) ->
        opts = {
            uri: @endpointUri
            headers: {
                'content-type':'application/x-www-form-urlencoded'
                'accept':'application/sparql-results+json'
            }
            body: querystring.stringify (query:query)
            encoding: 'utf8'
        }
        request.post opts, (err, res, body) ->
            if err
                return callback err
            return callback null, JSON.parse(body).results.bindings
sparqlClient = new SparqlClient dbconf.sparqlEndpoint

RegExp.escape = (s)->
    s.replace /[-\/\\^$*+?.()|[\]{}]/g, '\\$&'


class Engine

    schema: null
    rdfSchema: {
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#type': {
            id: 'type'
            title: 'type'
            type: 'uri'

        }
    }
    fullSchema: {}

    constructor: (@graph) ->
        unless @graph?
            @graph = dbconf.defaultGraph
        unless @schema
            @loadSchema (err, results) ->
                if err
                    throw err
                console.log 'schema loaded'

    loadSchema: (callback) =>
        schemaQuery = """
        SELECT DISTINCT ?object ?objectTitle ?predicate ?predicateTitle ?type isLiteral(?o) as ?isLiteral FROM <#{@graph}> WHERE {
            ?s a ?object .
            ?s ?predicate ?o .
            OPTIONAL {?o a ?_type .}
            OPTIONAL {?object <http://purl.org/dc/elements/1.1/title> ?objectTitle .}
            OPTIONAL {?predicate <http://purl.org/dc/elements/1.1/title> ?predicateTitle .}
            BIND(COALESCE(datatype(?o), ?_type ) as ?type) .
            FILTER (?predicate != <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>)
        }
        ORDER BY ?object ?predicate
        """
        @sparql schemaQuery, (err, data) =>
            if err
                return callback err
            @schema = {}
            for item in data
                objType = item.object.value.split("/")[-1..][0]
                unless @schema[objType]?
                    @schema[objType] = {
                        type: {
                            uri: item.object.value
                            title: item.objectTitle?.value or item.object.value
                            relation: true
                            type: "type"
                        }
                    }
                    @rdfSchema[item.object.value] = {}
                predicateID = item.predicate.value.split("/")[-1..][0].split("#")[-1..][0]
                predicateTitle = item.predicateTitle?.value or predicateID

                unless @schema[objType][predicateID]?
                    isRelation = not _.str.toBoolean item.isLiteral.value
                    @schema[objType][predicateID] = {
                        title: predicateTitle
                        uri: item.predicate.value
                        relation: isRelation
                        facet: if item.type.value is "http://www.w3.org/2001/XMLSchema#integer" then "sum"  else isRelation
                        type: item.type.value
                    }
                    @rdfSchema[item.predicate.value] = {
                        title: predicateTitle
                        id: predicateID
                        type: item.type.value
                    }
                    unless @fullSchema[predicateID]?
                        @fullSchema[predicateID] = {
                            title: predicateTitle
                            type: @rdfSchema[item.predicate.value].type
                            uri: @schema[objType][predicateID].uri
                            relation: @schema[objType][predicateID].relation
                            facet: @schema[objType][predicateID].facet
                            inTypes: []
                        }
                    @fullSchema[predicateID].inTypes.push objType
            console.log "=== schema =="
            console.log()
            console.log @schema
            console.log()
            console.log()
            console.log("=== rdfSchema ===")
            console.log()
            console.log()
            console.log @rdfSchema
            console.log()
            console.log()
            console.log("=== Full Schema ===")
            console.log()
            console.log()
            console.log @fullSchema
            console.log "=============================="
            return callback null, 'ok'


    parseQuery: (query) =>
        """
        :created_by=author/VincentRanwez&:has_concept=concept/Internet
        ->
            ?s <<created_by>> <<author/VincentRanwez>> .
            ?s <<has_concept>> <<concept/Internet>> .

        we can has multiple node match:
        :has_foo=3&x:has_foo=4&x:has_bar=2
        ->
            ?s <<has_foo> 3 .
            ?x <<has_foo>> 4 .
            ?x <<has_bar>> 2 .
        """
        sparqlQuery = []
        # objType = _.str.classify type
        for predicate, value of query
            operator = "="
            if ":" in predicate
                [subject, predicate] = predicate.split(':')
            assert.ok @fullSchema[predicate], "#{predicate} not known"
            if not subject
                subject = "s"
            if value.gt isnt undefined
                value = value.gt
                operator = ">"
            else if value.lt isnt undefined
                value = value.lt
                operator = "<"
            if not _.isArray(value)
                value = [value]
            for val, idx in value
                if operator is '='
                    if @fullSchema[predicate].relation
                        sparqlQuery.push "?#{subject} <<#{predicate}>> <<#{val}>> ."
                    else
                        dataType = @fullSchema[predicate].type
                        sparqlQuery.push "?#{subject} <<#{predicate}>> \"#{val}\"^^<#{dataType}> ."
                else
                    datatype = @fullSchema[predicate].type
                    sparqlQuery.push "?#{subject} <<#{predicate}>> ?_val#{idx} FILTER(?_val#{idx} #{operator} #{value}) ."
        sparqlQuery = sparqlQuery.join('\n')
        sparqlQuery



    processSubSparql: (subsparql) ->
        mapping = {}
        for part in subsparql.split("<<")[1..]
            value = part.split('>>')[0]
            if @fullSchema[value]?
                mapping[value] = @fullSchema[value].uri
            else
                mapping[value] = value
        for key, value of mapping
            regexp = new RegExp(RegExp.escape("<<#{key}>>"), "g")
            subsparql = subsparql.replace regexp, "<#{value}>"
        subsparql


    sparql: (sparqlQuery, callback) ->
        sparqlClient.query sparqlQuery, (err, data) ->
            if err
                return callback(err)
            return callback null, data


    subsparql: (subsparqlQuery, callback) =>
        sparqlQuery = @processSubSparql subsparqlQuery
        @sparql sparqlQuery, callback


    findOne: (id, callback) =>
        ###
        sparqlQuery = """SELECT DISTINCT * FROM <#{@graph}> WHERE {
            <#{id}> ?p ?o .
            {
                <#{id}> ?p ?o .
                FILTER isLiteral(?o)
            }
            UNION
            {
                <#{id}> ?p ?o .
                OPTIONAL {?o <http://purl.org/dc/elements/1.1/title> ?title .}
            }
        } LIMIT 50"""
        ###
        sparqlQuery = """
        SELECT DISTINCT ?predicate ?object ?title FROM <#{@graph}> WHERE {
            <#{id}> ?predicate ?object .
            OPTIONAL {?object <http://purl.org/dc/elements/1.1/title> ?_title .}
            BIND(COALESCE(?_title, ?object) as ?title)
        }
        """
        @sparql sparqlQuery, (err, data) =>
            # callback null, data
            obj = {uri: [id]}
            for item in data
                predicate = @rdfSchema[item.predicate.value]?.id
                if not obj[predicate]
                    obj[predicate] = []
                if item.object.type is 'uri'
                    unless (1 for i in obj[predicate] when i.uri is item.object.value).length
                        obj[predicate].push {uri: item.object.value, title: item.title.value}
                else
                    obj[predicate].push item.object.value
            for predicate, value of obj
                if value.length == 1
                    obj[predicate] = value[0]
            callback null, obj


    find: (options, callback) =>
        args = _.values(arguments)
        callback = args.pop()
        options = args.pop()
        if not _.isEmpty options.query
            subsparqlQuery = @parseQuery options.query
        else
            subsparqlQuery = "?s ?p ?o ."
        if options.type
            typeURI = @schema[_.str.classify options.type].type.uri
            subsparqlQuery += "?s a <#{typeURI}> ."
        subsparqlQuery = """SELECT ?s FROM <#{@graph}> WHERE {#{subsparqlQuery}} LIMIT 10"""
        sparqlQuery = @processSubSparql subsparqlQuery
        @sparql sparqlQuery, (err, data) =>
            if err
                return callback err
            docList = (item.s.value for item in data when item.s?.value)
            async.map docList, @findOne, (err, results) =>
                callback null, results


    #
    # options: {
    #   query (optional): the query
    #   type (optional): the type of the wanted objects
    # }
    #
    count: (callback) =>
        args = _.values(arguments)
        callback = args.pop()
        options = args.pop()
        if not _.isEmpty options.query
            subsparqlQuery = ""
            if options.type
                typeURI = @schema[_.str.classify options.type].type.uri
                subsparqlQuery = "?s a <#{typeURI}> . "
            subsparqlQuery += @parseQuery options.query
        else if options.type
            typeURI = @schema[_.str.classify options.type].type.uri
            subsparqlQuery = "?s a <#{typeURI}> . ?s ?p ?o ."
        else
            subsparqlQuery = "?s ?p ?o ."
        subsparqlQuery = """SELECT (count(DISTINCT ?s) as ?total) FROM <#{@graph}> WHERE {#{subsparqlQuery}}"""
        sparqlQuery = @processSubSparql subsparqlQuery
        @sparql sparqlQuery, (err, data) =>
            if err
                return callback err
            return callback null, data[0].total.value


    # options:
    #   type: type (optional)
    #   facet: facet (optional)
    #   query: query (optional)
    facet: (options, callback) =>
        assert.ok options.facet, "facet is required"
        parsedQuery = ""
        if options.type
            typeURI = @schema[_.str.classify options.type].type.uri
            parsedQuery += "?s a <#{typeURI}> ."
        if options.query
            parsedQuery += @parseQuery options.query
        
        subsparqlQuery = """SELECT ?o (count(?o) as ?occ)
            FROM <#{@graph}>
            WHERE {
                #{parsedQuery}
                ?s <<#{options.facet}>> ?o .
            }
            ORDER BY DESC(?occ)
            LIMIT 50"""
        sparqlQuery = @processSubSparql subsparqlQuery
        # console.time "facet"

        async.parallel {
            facets: (cb) =>
                @sparql sparqlQuery, (err, data) =>
                    if err
                        return callback err

                    facets = {}
                    values = []
                    for row in data
                        facets[row.o.value] = row.occ.value
                        values.push row.o.value

                    results = []
                    if @fullSchema[options.facet].relation
                        async.map values, @findOne, (err, data) ->
                            for item in data
                                if _.isArray(item.title) and item.title.length > 1
                                    item.title = item.title[0]
                                results.push {uri: item.uri, title: item.title or item.uri, count: facets[item.uri]}
                            # console.timeEnd 'facet'
                            cb null, results
                    else
                        for value, occ of facets
                            results.push {value: value, count: occ}
                        cb null, results
        
            stats: (cb) =>
                if  @fullSchema[options.facet].type is "http://www.w3.org/2001/XMLSchema#integer"
                    subsparqlQuery = """SELECT count(?s) as ?total max(?o) as ?max min(?o) as ?min avg(?o) as ?avg sum(?o) as ?sum
                        FROM <#{@graph}>
                        WHERE {
                            #{parsedQuery}
                            ?s <#{@fullSchema[options.facet].uri}> ?o .
                        }"""
                else
                    subsparqlQuery = """SELECT count(distinct ?o) as ?total
                        FROM <#{@graph}>
                        WHERE {
                            #{parsedQuery}
                            ?s <#{@fullSchema[options.facet].uri}> ?o .
                        }"""
                sparqlQuery = @processSubSparql subsparqlQuery
                @sparql sparqlQuery, (err, data) ->
                    statsResults = {}
                    for field, value of data[0]
                        if field is "avg"
                            statsResults[field] = Math.round(value.value)
                        else
                            statsResults[field] = value.value
                    cb null, statsResults

        }, (err, parallelResults) =>
            if err
                return callback err
            callback null, {
                facet: options.facet,
                title: @fullSchema[options.facet].title
                facets: parallelResults.facets,
                stats: parallelResults.stats
            }


    facets: (callback) =>
        args = _.values(arguments)
        callback = args.pop()
        options = args.pop()
        if options?.facet
            paramOptions = [options]
        else
            paramOptions = []
            if options?.type
                currentType = @schema[_.str.classify options.type]
                for fieldName, value of currentType when value.facet
                    option = _.clone options
                    option.facet = fieldName
                    paramOptions.push option
            else
                for fieldName, value of @fullSchema when value.facet
                    option = _.clone options
                    option.facet = fieldName
                    paramOptions.push option
        async.map paramOptions, @facet, callback


    describes: (callback) =>
        args = _.values(arguments)
        callback = args.pop()
        options = args.pop()
        if options?.type
            rdftype = _.str.classify options.type
            callback null, {type: options.type, fields: @schema[rdftype]}
         else
            callback null, {schema: @fullSchema}


    # collect the ids present in the query
    # and build a described query
    describeQuery: (options, callback) =>

        args = _.values(arguments)
        callback = args.pop()
        options = args.pop()
        query = options.query

        enhancedQuery = {}

        docIds = []
        proceedQuery = {}
        for predicate, ids of _.clone query
            if not proceedQuery[predicate]?
                proceedQuery[predicate] = []
                enhancedQuery[predicate] = []
            if not _.isArray ids
                ids = [ids]
            for id in ids
                if _.str.startsWith id, "http://"
                    docIds.push id
                    proceedQuery[predicate].push id
                else
                    enhancedQuery[predicate].push id

        # let's build an enhanced query which contains all the meta information needed
        async.map docIds, @findOne, (err, queryData) ->
            if err then return callback err
            queryInfos = {}
            for queryItem in queryData
                if _.isArray(queryItem.title) and queryItem.title.length > 1
                    queryItem.title = queryItem.title[0]
                queryInfos[queryItem.uri] = queryItem

            for predicate, value of proceedQuery
                if  _.isArray value
                    # enhancedQuery[predicate] = []
                    for val in value
                        enhancedQuery[predicate].push queryInfos[val]
                else
                    enhancedQuery[predicate] = queryInfos[value]
            return callback null, enhancedQuery


    all: (options, callback) =>
        type = options.type
        assert.ok type, "type is required"
        query = options.query
        async.parallel {
            #
            # get the documents which match the query
            #
            results: (cb) =>
                @find {type: type, query: query}, cb

            #
            # Number total of results
            #
            count: (cb) =>
                @count {type: type, query: query}, cb

            #
            # get all facets specified in the type.
            # Here, we are getting all "faceted" fields and then process them
            #
            facets: (cb) =>
                @facets {type: type, query: query}, cb

            #
            # We may want to be able to display the current made query beautifuly.
            # To do so, we have to fetch the entire document related to the id.
            #
            query: (cb) =>
                
                # collect the ids present in the query
                enhancedQuery = {}

                docIds = []
                proceedQuery = {}
                for predicate, ids of _.clone query
                    if not proceedQuery[predicate]?
                        proceedQuery[predicate] = []
                        enhancedQuery[predicate] = []
                    if not _.isArray ids
                        ids = [ids]
                    for id in ids
                        if _.str.startsWith id, "http://"
                            docIds.push id
                            proceedQuery[predicate].push id
                        else
                            enhancedQuery[predicate].push id

                # let's build an enhanced query which contains all the meta information needed
                async.map docIds, @findOne, (err, queryData) ->
                    queryInfos = {}
                    for queryItem in queryData
                        queryInfos[queryItem.uri] = queryItem

                    for predicate, value of proceedQuery
                        if  _.isArray value
                            # enhancedQuery[predicate] = []
                            for val in value
                                enhancedQuery[predicate].push queryInfos[val]
                        else
                            enhancedQuery[predicate] = queryInfos[value]
                    cb null, enhancedQuery

        }, (err, data) ->
            #
            # Here, we are collecting the results and aggregate them into a single object
            #
            if err
                return callback err

            results =
                type: type
                total: data.count
                query: data.query
                # currentQuery: currentQuery
                results: data.results
                facets: data.facets

            callback null, results

module.exports = Engine
