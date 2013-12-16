
_            = require 'underscore'
_.str        = require 'underscore.string'
request      = require 'request'
cheerio      = require 'cheerio'
crypto       = require 'crypto'
fs 			 = require 'fs'

# ## PubmedFetcher
# Fetch a publication from pubmed (NCBI)
module.exports = class PubmedFetcher

    constructor: (@cacheFileName) ->
        try
            file = fs.readFileSync("#{@cacheFileName}", {encoding: 'utf-8'})
            @cache = JSON.parse(file)
        catch error
            console.log "#{error}"
            @cache = {}

    sync: () ->
        console.log 'writing publications cache...'
        fs.writeFileSync("#{@cacheFileName}", JSON.stringify(@cache), {encoding: 'utf-8'})

    getUrlFromTitle: (title) ->
        publicationUrl = null
        if _.str.startsWith(title, 'http://www.ncbi.nlm.nih.gov/pubmed/')
            if '?' not in title
                title += '?'
            else
                title += '&'
            title += 'report=medline&format=text'
            url = title
        else
            title = title.replace('&', '%26')
            title = title.replace('#', '%23')
            url = "http://www.ncbi.nlm.nih.gov/pubmed/?report=medline&format=text&term=#{title}"
        return url

    _getCacheKey: (url) ->
        return crypto.createHash('sha1').update(url).digest('hex')

    fetch: (url, callback) =>
        cacheKey = @_getCacheKey(url)
        if @cache[cacheKey]?.pmid
            console.log  @cache[cacheKey]?.pmid, 'found'
            return process.nextTick () =>
                return callback null, @cache[cacheKey]
        
        else if @cache[cacheKey]?.error
            console.log 'XXX error found:', @cache[cacheKey]?.error
            return process.nextTick () =>
                callback null, null
        
        else
            waitFor = _.shuffle([2...5])[0]
            console.log "waiting for #{waitFor}..."
            setTimeout () =>
                try
                    @_fetch(url, callback)
                catch e
                    console.log "XXX: error found: #{e.message}"
                    callback e.message
            , waitFor*1000

    _fetch: (url, callback) ->
        cacheKey = @_getCacheKey(url)
        request.get {
            url: url
            headers: {
                'Host': 'www.ncbi.nlm.nih.gov'
                'Cache-Control': 'max-age=0'
                'Connection': 'keep-alive'
                # 'Cookie': 'clicknext=; prevsearch=; ncbi_prevPHID=396E47F42430A2F1000000000027876A; unloadnext=jsevent%3Dunloadnext%26ncbi_pingaction%3Dunload%26ncbi_timeonpage%3D18130%26ncbi_onloadTime%3D655%26jsperf_dns%3D0%26jsperf_connect%3D0%26jsperf_ttfb%3D912%26jsperf_basePage%3D124%26jsperf_frontEnd%3D547%26jsperf_navType%3D0%26jsperf_redirectCount%3D0%26maxScroll_x%3D0%26maxScroll_y%3D0%26currScroll_x%3D0%26currScroll_y%3D0%26hasScrolled%3Dfalse%26ncbi_phid%3D396E47F42430A2F1000000000027876A; ncbi_sid=CE89789B21382AD1_0023SID; WebEnv=1fOZ-r2gjHLC5zn7-v39ICuiE5FMJ44sJZsEIaoX7pH5H12MLUDIw_iK7YGIAB_VNGdbHH6gYwhvIeyrc_lvparLCtqJKGQ8z01AU%40CE89789B21382AD1_0023SID'
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/28.0.1500.71 Chrome/28.0.1500.71 Safari/537.36'
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                'Referer': 'https://www.google.fr/'
                # 'Accept-Encoding': 'gzip,deflate,sdch'
                'Accept-Language': 'fr-FR,fr;q=0.8,en-US;q=0.6,en;q=0.4'
            }
        }, (err, response, body) =>
            if err
                console.log err
                return callback err
            
            rawTitle = decodeURIComponent(response.request.href.split('&term=')[1])
            pmid = null
            title = null
            publishingYear = null
            meshConcepts = []
            authors = []
            languages = []
            checkTitleContinousLine = false

            $ = cheerio.load(body)
            medlineText = $('pre').text()

            # #### Handling errors

            # There is multiple publications which match the title
            if medlineText.split('PMID-').length > 2
                error = "too many publications found:: #{rawTitle}"
                console.log "XXX too many publications found: #{rawTitle}"
                @cache[cacheKey] = {error: error, tomany: true}
                return callback null, null
            
            # There is no match
            if not medlineText.trim()
                error = "no publication found:: #{rawTitle}"
                console.log "--XX>> publi not found: #{rawTitle}"
                @cache[cacheKey] = {error: error, notfound: true}
                return callback null, null
            
            # #### Processing Medline format
            for line in medlineText.split('\n')
                if _.str.startsWith(line, 'PMID-')
                    pmid = line.split('- ')[1]
                else if _.str.startsWith(line, 'MH ')
                    concept = _.str.clean(line.split(' - ')[1..].join(' - ').split('/')[0])
                    concept = _.str.lstrip(concept, '*')
                    conceptID = _.str.classify(concept)
                    meshConcepts.push({
                        id: conceptID
                        title: @escapeQuote(concept)
                    })
                else if _.str.startsWith(line, 'FAU ')
                    author = _.str.clean line.split('-')[1..].join('-')
                    authorID = _.str.classify(author)
                    if authorID
                        authors.push {id: authorID, title: @escapeQuote(author)}
                    else
                        console.log "ooooXXX author not found in: #{rawTitle}, #{line} >>> #{medlineText}"
                else if _.str.startsWith(line, 'LA ')
                    language = _.str.clean line.split('-')[1..].join('-')
                    language = language.toLowerCase()
                    languages.push @escapeQuote language
                else if _.str.startsWith(line, 'DP ')
                    publishingYear = _.str.clean(line.split('-')[1..].join('-')).split(' ')[0]
                else if _.str.startsWith(line, 'AID -') and _.str.endsWith(line, '[doi]')
                    doi = line.split(' - ')[1..].join(' - ').split(' [doi]')[0]
                else if _.str.startsWith(line, 'TI ')
                    title = _.str.clean line.split(' - ')[1..].join(' - ')
                    checkTitleContinousLine = true
                else if _.str.startsWith(line, '  ') and checkTitleContinousLine
                    title += ' '+_.str.clean line
                else if not _.str.startsWith(line, '  ') and checkTitleContinousLine
                    checkTitleContinousLine = false
            
            # #### Building the publication
            if pmid
                publi = {
                    pmid: pmid
                    title: @escapeQuote(title)
                    meshConcepts: meshConcepts
                    authors: authors
                    languages: languages
                    publishingYear: publishingYear
                    doi: doi
                    url: url # usefull to prevent fetching the publication again on update
                }

                if languages.length > 1
                    console.log 'XXXX languages', pmid, languages
                
                @cache[cacheKey] = publi
                return callback null, publi
            else
                console.log 'XX>>> no PMID'
                error = "no PMID:: #{rawTitle}"
                @cache[cacheKey] = {error: error, nopmid: true}
                return callback null, null

    escapeQuote: (text)->
        text.replace(/"/g, '\\"')


if require.main is module
    pmf = new PubmedFetcher('publicached.json')
    pmf.fetch 'http://www.ncbi.nlm.nih.gov/pubmed/?report=medline&format=text&term=Cofilin Activation during Podosome Belt Formation in Osteoclasts. Anne Blangy, Heiani Touaitahuata, Gaelle Cres, Geraldine Pawlak. 2012 PLoS ONE DOI 10.1371/journal.pone.0045909', (err, data) ->
        if err
            throw err
        console.log data