
# The ITCancerProcessor aims to process the team of the itmo cancer.

# The data is in a MySQL database from a cube (ask LGI2P). It can be found here (TODO)

_            = require 'underscore'
_.str        = require 'underscore.string'
fs           = require 'fs'
async        = require 'async'
mysql        = require 'mysql'
rdfParser    = require('./itcancer-rdf-parser').rdfParser
PubmedFetcher = require('./pubmed-fetcher')


# The ITCancerProcessor is the object which will parse the database and export
# the data into [Turtle format](http://en.wikipedia.org/wiki/Turtle_RDF)

# The usage is pretty simple:

#     processor = new ITCancerProcessor({
#       host     : 'localhost'
#       user     : 'root'
#       password : 'mysql'
#       database : 'annu_itmo'
#       fileName : 'out.ttl'
#       publicationCache: 'publicache.json'
#     })
#     processor.run()

module.exports = class ITCancerProcessor

    # the constructor take the config object which look like:

    #  * **fileName**:         the output file name in turtle format (`out.ttl` by default)
    #  * **publicationCache**: the file name where the fetched publication will be cached in JSON (`out.json` by default)
    #  * **host**:             the database hostname (`localhost` by default)
    #  * **user**:             the database user
    #  * **password**:         the database password
    #  * **database**:         the database name (`annu_itmo` by default)
    constructor: (config) ->
        @fileName = config.fileName or 'out.ttl'
        @pool = mysql.createPool {
            host: config.host or 'localhost'
            user: config.user
            password: config.password
            database: config.database or 'annu_itmo'
        }
        if not config.publicationCache
            throw "publicationCache file name not found in config: #{config}"
        @pubmedFetcher = new PubmedFetcher(config.publicationCache)

    # Load all teams from the database
    loadTeams: (callback) ->
        console.log 'loading teams...'
        @pool.getConnection (err, connection) ->
            if err
                return callback err
            query = """
                SELECT * FROM `annu_itmo`
            """
            connection.query query, (err, rows, fields)->
                if err
                    return callback err
                connection.release();
                return callback null, rows
    
    # Run the export process.
    # For each team, call the processNode function.
    run: (callback) ->
        console.log "output to #{@fileName}"
        @loadTeams (err, teams) =>
            if err
                return callback err
            console.log "#{teams.length} teams loaded"
            # process the teams 5 by 5
            async.eachLimit teams, 5, @processTeam.bind(@), (err)=>
                if err
                    throw err
                console.log '...done'
                @sync()
                return callback null, 'ok'



    # ## Process a team.
    # This is where the serious stuff is done.
    processTeam: (item, callback) ->
        # we only want teams who has a usual name (to display them)
        # if a team has no usual name, we log it and continue to process the other teams
        usualName = @clean @escapeQuote item.AI_TEAM_USUAL_NAME
        unless usualName
            console.log "XXX error:, #{item.AI_ID} has no usual name"
            return callback null, null

        # Let's store the teamID as we will need it all the way
        teamID = item.AI_ID

        # #### let's build a team...
        team = {
            id: teamID
            title: usualName
            leaders: []
            affiliations: []
            keywords: []
            methodologicals: []
            bioResources: []
        }

        # if the team has specified their zip code, we extract the county (aka postal code)
        zip_code = @clean item.AI_CP
        if zip_code
            team.zip_code = zip_code
            team.county = zip_code[...2]

        # Process all field in parallel. When all process are finished,
        # pass the results to the `exportTeam` method
        async.parallel {
            leaders: (cb) => @_processLeaders(item, cb)
            statsPeople: (cb) => @_processStatsPeople(item, cb)
            affiliations: (cb) => @_processAffiliations(item, cb)
            otherAffiliations: (cb) => @_processOtherAffiliations(item, cb)
            mainItmo: (cb) => @_processMainItmo(item, cb)
            secondaryItmo: (cb) => @_processSecondatyItmo(item, cb)
            keywords: (cb) => @_processKeywords(item, cb)
            methodologicals: (cb) => @_processMethodologicals(item, cb)
            bioResources: (cb) => @_processBioResources(item, cb)
            approaches: (cb) => @_processApproaches(item, cb)
            publications: (cb) => @_processPublications(item, cb)
        }, (err, teamData) =>
            if err
                @pubmedFetcher.sync()
                return
            
            # Fill the team with the data
            team.leaders = teamData.leaders
            for key, value of teamData.people
                team[key] = value

            team.affiliations = teamData.affiliations
            Array::push.apply(team.affiliations, teamData.otherAffiliations)
            team.mainItmo = teamData.mainItmo
            team.secondaryItmo = teamData.secondatyItmo

            for key, value of teamData.statsPeople
                team[key] = value

            team.keywords = teamData.keywords
            team.methodologicals = teamData.methodologicals
            team.bioResources = teamData.bioResources

            for key, value of teamData.approaches
                console.log "#{key}, #{value}"
                team[key] = value

            team.publications = (publi for publi in teamData.publications when publi?.pmid)

            @toTurtle team
            return callback null, 'ok'


    toTurtle: (team) =>
        teamrdf = rdfParser.classes.team.new({id: team.id, title: team.title})

        # County (or "postal code")
        if team.county
            countyrdf = rdfParser.classes.county.new({id: team.county, title: team.county})
            teamrdf.addRelation(countyrdf)

        # Leaders
        for leader in team.leaders
            leaderrdf = rdfParser.classes.leader.new({id: leader.id, title: leader.title})
            teamrdf.addRelation(leaderrdf)

        # People statistics
        if team.nbResearchers
            teamrdf.addProperty(rdfParser.properties.nbResearchers.new(team.nbResearchers))
        if team.nbTechnicians
            teamrdf.addProperty(rdfParser.properties.nbTechnicians.new(team.nbTechnicians))
        if team.nbPostdocs
            teamrdf.addProperty(rdfParser.properties.nbPostdocs.new(team.nbPostdocs))
        if team.nbPhds
            teamrdf.addProperty(rdfParser.properties.nbPhds.new(team.nbPhds))

        # Affiliations
        for affiliation in team.affiliations
            teamrdf.addRelation rdfParser.classes.affiliation.new({id: affiliation.id, title: affiliation.title})

        # ITMO
        if team.mainItmo
            teamrdf.addRelation rdfParser.classes.mainItmo.new({id: team.mainItmo.id, title: team.mainItmo.title})
        if team.secondaryItmo
            console.log '######>>>>>', team.secondaryItmo
            teamrdf.addRelation rdfParser.classes.secondaryItmo.newx({id: team.secondaryItmo.id, title: team.secondaryItmo.title})

        # Divers
        if team.nbPatents
            teamrdf.addProperty rdfParser.properties.nbPatents.new(team.nbPatents)
        if team.nbResearchGrants
            teamrdf.addProperty rdfParser.properties.nbResearchGrants.new(team.nbResearchGrants)
        if team.nbIndustrialPartnerships
            teamrdf.addProperty rdfParser.properties.nbIndustrialPartnerships.new(team.nbIndustrialPartnerships)

        # Keywords
        for keyword in team.keywords
            teamrdf.addRelation rdfParser.classes.keyword.new({title: keyword.title, id: keyword.id })

        # Methodologicals
        for methodo in team.methodologicals
            teamrdf.addRelation rdfParser.classes.methodological.new({title: methodo.title, id: methodo.id })

        # Bio resources
        for biores in team.bioResources
            teamrdf.addRelation rdfParser.classes.bioResource.new({title: biores.title, id: biores.id })

        # Publications
        for publication in team.publications
            publicationrdf = rdfParser.classes.publication.new({id: publication.pmid, title: publication.title})
            for meshConcept in publication.meshConcepts
                meshconceptrdf = rdfParser.classes.meshConcept.new({id: meshConcept.id, title: meshConcept.title})
                publicationrdf.addRelation meshconceptrdf
                teamrdf.addRelation meshconceptrdf
            for author in publication.authors
                if author.id
                    publicationrdf.addRelation rdfParser.classes.author.new({id: author.id, title: author.title})
            for lang in publication.languages
                publicationrdf.addRelation rdfParser.classes.language.new({id: lang, title: lang})
            publicationrdf.addRelation rdfParser.classes.publishingYear.new({id: publication.publishingYear, title: publication.publishingYear})
            teamrdf.addRelation publicationrdf

        fs.appendFileSync "#{@fileName}",  teamrdf.stringify()+'\n', 'utf-8'


    # Team parallel processing
    # ------------------------
    # The following methods are launched in parallel in the `processTeam` method
    

    # Process the **leader** fields (there are sometime two leader in a team)
    _processLeaders: (item, callback) ->
        results = []
        for leaderIdx in [1..2]
            if @clean item["AI_TEAM_LEADER_NAME#{leaderIdx}"]
                leaderName = item["AI_TEAM_LEADER_NAME#{leaderIdx}"]
                leaderSurname = item["AI_TEAM_LEADER_SURNAME#{leaderIdx}"]
                leaderTitle = @clean "#{leaderName} #{leaderSurname}"
                # `leaderID` is build by the classify method. Ex: 'James Smith' -> 'JamesSmith'
                leaderID = _.str.classify leaderTitle
                results.push {id: leaderID, title: leaderTitle}
        return callback null, results


    # Process some **stats about people** who are working in the team:
    #
    #  * `AI_RESEARCH_TEAM_RESEARCHERS`: number of researchers
    #  * `AI_RESEARCH_TEAM_TECHNICIANS`: number of technicians
    #  * `AI_RESEARCH_TEAM_POSTDOC`: number of post-PHDs
    #  * `AI_RESEARCH_TEAM_PHD`: number of PHDs
    _processStatsPeople: (item, callback) ->
        results = {}
        unless _.isNaN _.str.toNumber item.AI_RESEARCH_TEAM_RESEARCHERS
            results.nbResearchers = item.AI_RESEARCH_TEAM_RESEARCHERS

        unless _.isNaN _.str.toNumber item.AI_RESEARCH_TEAM_TECHNICIANS
            results.nbTechnicians = item.AI_RESEARCH_TEAM_TECHNICIANS
        
        unless _.isNaN _.str.toNumber item.AI_RESEARCH_TEAM_POSTDOC
            results.nbPostdocs = item.AI_RESEARCH_TEAM_POSTDOC
        
        unless _.isNaN _.str.toNumber item.AI_RESEARCH_TEAM_PHD
            results.nbPhds = item.AI_RESEARCH_TEAM_PHD
        return callback null, results


    # Process **team's affiliation**. The affiliation here is a **foreign key**.
    _processAffiliations: (item, callback) =>
        results = []
        for affiliationIdx in [1..2]
            fieldName = "AI_RESEARCH_ORGANISMS_AFFILIATION#{affiliationIdx}"
            if @clean item[fieldName]
                affiliationID = item[fieldName]
                if affiliationID isnt parseInt('0')
                    results.push {name: "AI_RESEARCH_ORGANISMS_AFFILIATION#{affiliationIdx}", value: affiliationID}
        # if there are affiliations, fetch the title in the foreign tables with the method `getAffilitationTitle`
        if results
            async.map results, @getAffiliationTitle, (err, data) ->
                if err
                    return callback err
                return callback null, data
        else
            return callback null, []


    # Process **text free affiliation**. We are talking here of university and other organisms
    _processOtherAffiliations: (item, callback) =>
        results = []
        if @clean item.AI_RESEARCH_ORGANISMS_UNIVERSITY
            university = @escapeQuote @clean item.AI_RESEARCH_ORGANISMS_UNIVERSITY
            universityID = _.str.classify university
            results.push {id: universityID, title: university}
            
        if @clean item.AI_RESEARCH_ORGANISMS_OTHER
            otherOrganism = @escapeQuote @clean item.AI_RESEARCH_ORGANISMS_OTHER
            otherOrganismID = _.str.classify otherOrganism
            results.push {id: otherOrganismID, title: otherOrganism}

        return callback null, results

    # Process the **main ITMO** the team is affiliated to. The mainItmoID is a **foreig key**,
    # so we have to fetch its title via `getAffiliationTitle`
    _processMainItmo: (item, callback) =>
        if item.AI_AVIESAN_MAIN_AFFILIATION
            mainItmoID = @clean item.AI_AVIESAN_MAIN_AFFILIATION
            @getAffiliationTitle {name: 'AI_AVIESAN_MAIN_AFFILIATION', value: mainItmoID}, (err, res) ->
                return callback null, res
        else
            return callback null, null

    # Process the **secondary ITMO** the team is affiliated to. The secondaryItmoID is a **foreign key**,
    # so we have to fetch its title via `getAffiliationTitle`
    _processSecondatyItmo: (item, callback) =>
        if item.AI_AVIESAN_SECONDARY_AFFILIATION
            secondaryItmoID = @clean item.AI_AVIESAN_SECONDARY_AFFILIATION
            @getAffiliationTitle {name: 'AI_AVIESAN_SECONDARY_AFFILIATION', value: secondaryItmoID}, (err, res) ->
                return callback null, res
        else
            return callback null, null

    # Process the team's **keywords** (text free)
    _processKeywords: (item, callback) =>
        results = []
        for kwIdx in [1..5]
            if item["AI_RESEARCH_KW#{kwIdx}"]
                keyword = item["AI_RESEARCH_KW#{kwIdx}"]
                keyword = @escapeQuote @clean keyword
                keyword = keyword.toLowerCase()
                for key in keyword.split(',')
                    key = @clean key
                    keyID = _.str.classify(key)
                    if keyID
                        results.push {id: keyID, title: key}
        return callback null, results

    # Process the team's **methodologicals** (text free)
    _processMethodologicals: (item, callback) =>
        results = []
        for methIdx in [1..5]
            if item["AI_METHODOLOGICAL_KW#{methIdx}"]
                method = item["AI_METHODOLOGICAL_KW#{methIdx}"]
                method = @escapeQuote @clean method
                method = method.toLowerCase()
                methodID = _.str.classify(method)
                if methodID
                    results.push {id: methodID, title: method}
        return callback null, results

    # Process the team's **bio resources** (text free)
    _processBioResources: (item, callback) =>
        results = []
        for bioIdx in [1..5]
            if item["AI_BIOLOGICAL_RESOURCES#{bioIdx}"]?
                bio = item["AI_BIOLOGICAL_RESOURCES#{bioIdx}"]
                bio = @escapeQuote @clean bio
                bio = bio.toLowerCase()
                if bio
                    results.push {id: _.str.classify(bio), title: bio}
        return callback null, results

    # Process team's **approaches**, which are:
    #
    #  * patents
    #  * industry
    #  * clinical
    _processApproaches: (item, callback) =>
        results = {}
        unless _.isNaN _.str.toNumber item.AI_TRANSLATIONAL_APPROACHES_PATENTS
            results.nbPatents = item.AI_TRANSLATIONAL_APPROACHES_PATENTS
            
        unless _.isNaN _.str.toNumber item.AI_TRANSLATIONAL_APPROACHES_INDUSTRY
            results.nbIndustrialPartnerships = item.AI_TRANSLATIONAL_APPROACHES_INDUSTRY 

        unless _.isNaN _.str.toNumber item.AI_TRANSLATIONAL_APPROACHES_CLINICAL
            results.nbResearchGrants = item.AI_TRANSLATIONAL_APPROACHES_CLINICAL
        return callback null, results


    _processPublications: (item, callback) =>
        publicationUrls = []
        for pubidx in [1..6]
            if item["AI_EXCERPT_PUBLICATIONS#{pubidx}"]
                publicationTitle = @clean item["AI_EXCERPT_PUBLICATIONS#{pubidx}"]
                if publicationTitle
                    publicationUrls.push @pubmedFetcher.getUrlFromTitle(publicationTitle)
        
        async.mapSeries publicationUrls, @pubmedFetcher.fetch, (err, data) ->
            if err
                return callback err
            return callback null, data


    # Util methods
    # ------------

    # `getAffiliationTitle` is used to fetch the affiliations title from foreign tables
    getAffiliationTitle: (field, callback) =>
        @pool.getConnection (err, connection) =>
            query = """
                SELECT DISTINCT labels.L_TRANSLATION
                FROM `annu_itmo` as annu, `kw_keywords` as kw, `LABELS`  as labels
                WHERE 
                    annu.#{field.name} = #{field.value} and
                    kw.KW_ID = annu.#{field.name} and
                    kw.KW_TERM=labels.L_IDENT"""
            connection.query query, (err, rows, fields)=>
                if err
                    return callback err
                connection.release();
                title = @clean _.str.strip rows[0].L_TRANSLATION
                return callback null, {id: _.str.classify(title), title: title}


    # Clean the text: trim it, and remove multiple whitespace.
    # If the text is 'nc' or '-', it is considerated like an empty string
    clean: (text) ->
        text = _.str.clean text
        if not text or text.toLowerCase() in ['nc', '-']
            return ""
        return text

    # Escape quotes (turtle format doesn't like them)
    escapeQuote: (text)->
        text.replace(/"/g, '\\"')

    sync: () ->
        console.log "sync"
        @pubmedFetcher.sync()


if require.main is module

    processor = new ITCancerProcessor {
      host     : 'localhost'
      user     : 'root'
      password : 'mysql'
      database : 'annu_itmo'
      fileName : 'results.ttl'
      publicationCache: 'publicached.json'
    }

    process.on 'SIGINT', () =>
        console.log('Received TERM signal');
        processor.sync()
        process.exit(1)

    processor.run (err, ok)->
        if err
            throw err
        process.exit(1)
