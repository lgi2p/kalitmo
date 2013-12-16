#!/usr/bin/env coffee
# Update the Kalitmo database from Cube
# -------------------------------------


ITCancerProcessor = require './dataimporter/itcancerprocessor'
config = require('../../config.json')

 # * Import the the data dump into the `annu_itmo` mysql's database

# exec "mysql -u root -u mysql ..."


projectPath = "#{__dirname}/../.."
results_data = "#{projectPath}/data/results.ttl"

# * Configure the processor

processor = new ITCancerProcessor {
    host     : config.mysqlHost
    user     : config.mysqlUser
    password : config.mysqlPassword
    database : config.mysqlItmoDatabase
    fileName : results_data
    publicationCache: "#{projectPath}/data/publicached.json"
}

# take care of TERMs signal
process.on 'SIGINT', () =>
    console.log('Received TERM signal');
    processor.sync()
    process.exit(1)

# * Launch the script which will process 

processor.run (err, ok)->
    if err
        throw err
    process.exit(1)

    # fs   = require 'fs'
    # exec = require('child_process').exec
    # path = require 'path'
    # zlib = require 'zlib'


    # uniq_results_data = "#{projectPath}/data/results.uniq.ttl"
    # mesh_ontology_data = "#{projectPath}/data/mesh_ontology.ttl"
    # tmp_mesh_ontology_data = "/tmp/mesh_ontology.ttl"
    # tmp_results_data = "/tmp/results.ttl"

    # # * Clean old data

    # if fs.existsSync results_data
    #     fs.unlinkSync results_data
    # if fs.existsSync uniq_results_data
    #     fs.unlinkSync uniq_results_data

    # if fs.existsSync tmp_mesh_ontology_data
    #     fs.unlinkSync tmp_mesh_ontology_data

    # # copy the file
    # fs.createReadStream(mesh_ontology_data).pipe(fs.createWriteStream(tmp_mesh_ontology_data))

    # graphURI = config.defaultGraph

    # # drop the existing database
    # console.log "droping the existing database: <#{graphURI}>:"
    # console.log "isql exec=\"SPARQL CLEAR GRAPH <#{graphURI}>;\""
    # exec "isql exec=\"SPARQL CLEAR GRAPH <#{graphURI}>;\"", (err, out) ->
    #     console.log 'XXX', err
    #     console.log out
    #     console.log '-----'
    #     if err
    #         throw err
    #     exec "isql exec=\"SPARQL SELECT count(*) from <#{graphURI}> WHERE {?s ?o ?p .};\"", (err, out) ->
    #         console.log 'XXX', err
    #         console.log out
    #         console.log '-----'
    #         # import the mesh ontology
    #         console.log "importing mesh ontology data...:"
    #         console.log "isql exec=\"DB.DBA.TTLP (file_to_string_output ('#{tmp_mesh_ontology_data}'), '', '#{graphURI}', 64);\""
    #         console.log 'yyy'
    #         exec "isql exec=\"DB.DBA.TTLP (file_to_string_output ('#{tmp_mesh_ontology_data}'), '', '#{graphURI}', 64);\"", (err, out) ->
    #             console.log 'XXX', err
    #             console.log out
    #             console.log '-----'
    #             if err
    #                 throw err
            
    #             # remove duplicated lines
    #             console.log "removing duplicated lines from #{results_data} to #{uniq_results_data}...:"
    #             console.log "sort -u #{results_data} > #{uniq_results_data}"
    #             exec "sort -u #{results_data} > #{uniq_results_data}", (err, out)->
    #                 console.log 'XXX', err
    #                 console.log out
    #                 console.log '-----'
    #                 if err
    #                     throw err

    #                 if fs.existsSync tmp_results_data
    #                     fs.unlinkSync tmp_results_data

    #                 console.log "copying #{uniq_results_data} to #{tmp_results_data}..."
    #                 fs.createReadStream(uniq_results_data).pipe(fs.createWriteStream(tmp_results_data))

    #                 # import itcancer data
    #                 console.log "importing itcancer data...:"
    #                 console.log "isql exec=\"DB.DBA.TTLP (file_to_string_output ('#{tmp_results_data}'), '', '#{graphURI}', 64);\""
    #                 exec "isql exec=\"DB.DBA.TTLP (file_to_string_output ('#{tmp_results_data}'), '', '#{graphURI}', 64);\"", (err, out) ->
    #                     console.log 'XXX', err
    #                     console.log out
    #                     console.log '-----'
    #                     if err
    #                         throw err

    #                     console.log  "zipping to #{projectPath}/public/db.ttl.gz"
    #                     gzip = zlib.createGzip()
    #                     inp = fs.createReadStream(tmp_results_data)
    #                     out = fs.createWriteStream("#{projectPath}/public/db.ttl.gz")

    #                     inp.pipe(gzip).pipe(out)

    #                     out.on 'finish', () ->
    #                         console.log "...done"
    #                         process.exit(1)
