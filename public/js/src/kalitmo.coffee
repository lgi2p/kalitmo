
window.app or= {}

app = window.app


class app.Documents extends Backbone.Collection

    name: 'documents' # used for loadingFinished

    fetch: (type, queryString) ->
        @trigger 'loading'
        $.getJSON "/api/#{type}/documents#{queryString}", (data) =>
            @.reset data.results


class app.Facets extends Backbone.Collection

    name: 'facets' # used for loadingFinished

    fetch: (type, queryString) ->
        @trigger 'loading'
        $.getJSON "/api/#{type}/facets#{queryString}", (data) =>
            @.reset data.results


class app.Query extends Backbone.Model

    fetch: (type, queryString) ->
        @trigger 'loading'
        if queryString and queryString[0] isnt '?'
            queryString = "?#{queryString}"
        @.clear()
        $.getJSON "/api/#{type}/query#{queryString}", (data) =>
            @.set data.results


class app.TotalCount extends Backbone.Model

    fetch: (type, queryString) ->
        @.clear {silent: true}
        @.set 'loading', true
        $.getJSON "/api/#{type}/count#{queryString}", (data) =>
            @.set {total: data.results}


class app.Control extends Backbone.Model

    initialize: () ->
        @.query = new app.Query()
        @.documents = new app.Documents()
        @.facets = new app.Facets()
        @.count = new app.TotalCount()


    fetch: (type, params) ->
        @trigger 'loading'
        query = []
        for key, values of params
            values = [values] unless _.isArray(values)
            for value in values
                if value
                    query.push "#{key}=#{encodeURI(value)}"
        query = query.join('&')
        queryString = if query then "?#{query}" else ''

        @set {'type': type, queryString: queryString}

        @.query.fetch(type, queryString)
        @.documents.fetch(type, queryString)
        @.facets.fetch(type, queryString)
        @.count.fetch(type, queryString)

    changeFormat: (format) ->
        @set 'format', format

    addToQuery: (predicate, uri) ->
        params = {}
        params[predicate] = [encodeURI(uri)]
        for item, values of @.query.toJSON()
            unless params[item]?
                params[item] = []
            unless _.isArray values
                values = [values]
            for val in values
                params[item].push encodeURI(val.uri)
        @.fetch @get('type'), params

    removeFromQuery: (predicate, uri) ->
        params = {}
        for item, values of @.query.toJSON()
            unless params[item]?
                params[item] = []
            unless _.isArray values
                values = [values]
            for val in values
                unless item is predicate and val.uri is uri
                    params[item].push encodeURI(val.uri)
        @.fetch @get('type'), params

    replaceQuery: (predicate, uri)->
        params = {}
        params[predicate] = encodeURI(uri)
        @.fetch @get('type'), params


class app.FacetsView extends Backbone.View

    template: Handlebars.compile """
        {{#ifFacetStats facets}}
            <h4>Stats</h4>
            <ul class="no-bullet">
                {{#eachFacetStats facets}}
                    <li data-toggleinfo>
                        ~{{stats.avg}} {{title}} <small><a href="#" data-action="showMore">more</small></a>
                        <ul class="no-bullet hidden moreinfo">
                            {{#each stats}}
                                <li>{{@key}} {{this}}</li>
                            {{/each}}
                        </ul>
                    </li>
                {{/eachFacetStats}}
            </ul>
        {{/ifFacetStats}}

        {{#ifFacetRelations facets}}
            <h4> Related </h4>
            {{#eachFacetRelations facets}}
                <h5>{{title}}</h5>
                <ul class="no-bullet">
                    {{#each facets}}
                        <li>
                            <a href="#" data-action='addToQuery' data-predicate="{{../facet}}" data-uri="{{uri}}">[+]</a>
                            <a href="#" data-action='replaceQuery' data-predicate="{{../facet}}" data-uri="{{uri}}">
                                {{title}}
                            </a>
                            {{count}}
                        </li>
                    {{/each}}
                </ul>
            {{/eachFacetRelations}}
        {{/ifFacetRelations}}
    """

    initialize: () ->
        @listenTo @collection, 'reset', @render
        @listenTo @collection, 'loading', @loading

    loading: () ->
        @$el.html ''
        @.trigger 'rendered'

    render: () ->
        @$el.html @template {facets: @collection.toJSON()}
        @.trigger('rendered')


class app.DocumentsView extends Backbone.View

    name: 'documentsview'

    template: Handlebars.compile """
        {{#each documents}}
            <fieldset class="alpha">
            <legend>{{type.title}}</legend>
            {{#eachLiterals this}}
                <p><b>{{@key}}</b>
                    {{#if uri}}
                        <a href="#" data-action="replaceQuery" data-predicate="{{@key}}" data-uri="{{uri}}">
                        {{#if title}}
                            {{title}}
                        {{else}}
                            {{uri}}
                        {{/if}}
                        </a>
                    {{else}}
                        {{this}}
                    {{/if}}
                </p>
            {{/eachLiterals}}

            {{#eachArrays this}}
                <div class="small-4 columns">
                    <h5>{{@key}}</h5>
                    <ul class="no-bullet">
                    {{#eachSlice this 0 5}}
                        <li>
                            <a href="#" data-action='addToQuery' data-predicate="{{@key}}" data-uri="{{uri}}">[+]</a>
                            <a href="#" data-action='replaceQuery' data-predicate="{{@key}}" data-uri="{{uri}}">
                                {{title}}
                            </a>
                        </li>
                    {{/eachSlice}}
                    </ul>
                </div>
            {{/eachArrays}}
            </fieldset>
        {{/each}}
    """

    initialize: () ->
        @listenTo @collection, 'reset', @render
        @listenTo @collection, 'loading', @loading

    loading: ()->
        @$el.html ''
        @.trigger 'rendered', @

    render: ()->
        documentsCollection = @collection.toJSON()
        template = @template
        if documentsCollection.length > 0
            type = documentsCollection[0].type.title
            html = $("#template-#{type}").html()
            if html
                template = Handlebars.compile(html)
        @$el.html template {documents: documentsCollection}
        @.trigger 'rendered', @


class app.StatsView extends Backbone.View

    name: 'statsview'

    template: Handlebars.compile """
        <div>
            {{#each facets}}
                {{#displayFacet this}}
                    <div class="chart" id="stats-container-{{@index}}"></div>
                {{/displayFacet}}
            {{/each}}
        </div>
    """

    chartOptions: {
        chart: {
            height: 1000
            type: 'bar'
        }
        title: {
            text: ''
        }
        subtitle: {
            text: ''
        }
        xAxis: {
            categories: []
            labels: {
                overflow: 'justify'
            }
        }
        legend: false
        yAxis: {
            min: 0,
            title: {
                text: '',
                align: 'high'
            },
            labels: {
                overflow: 'justify'
            }
        },
        plotOptions: {
            bar: {
                dataLabels: {
                    enabled: true
                }
            }
        }
        credits: {
            enabled: false
        }
        series: [{
            name: ''
            data: []
        }]
    }


    initialize: () ->
        @listenTo @collection, 'reset', @render
        @listenTo @collection, 'loading', @loading

    loading: ()->
        @$el.html ''
        @.trigger 'rendered', @

    render: ()->
        @jsloaded = false
        facets = @collection.toJSON()
        @$el.html @template {facets: facets}
        @.trigger 'rendered', @

    loadJS: ()->
        facets = @collection.toJSON()
        for facet, index in facets
            if facet.facets.length > 1
                if facet.facet is 'county'
                    mapData = {}
                    for item in facet.facets
                        jvectorId = JVectorByCode[item.title]?.id
                        unless mapData[jvectorId]?
                            mapData[jvectorId] = 0
                        mapData[jvectorId] += parseInt(item.count)

                    @$("#stats-container-#{index}").vectorMap({
                        map: 'fr_merc_en',
                        backgroundColor: 'gray',

                        series: {
                            regions: [{
                                values: mapData,
                                scale: ['#C8EEFF', '#0071A4'],
                                normalizeFunction: 'polynomial'
                            }]
                        },
                        hoverOpacity: 0.7,
                        hoverColor: false
                        onRegionLabelShow: (evt, label, code) ->
                            count = if mapData[code] then mapData[code] else 0
                            label.html "#{label.html()} (#{count})"
                    })
                else
                    options = _.clone(@chartOptions)
                    options.title.text = facet.title
                    if facet.facet is 'publishing_year'
                        data = _.sortBy facet.facets, (item) ->
                            -parseInt(item.title)
                    else
                        data = facet.facets
                    options.xAxis.categories = []
                    #(category.title for category in data)
                    for category in data
                        title = category.title
                        if _.isString(title) and title.length > 45
                            title = "#{title[..45]}..."
                        options.xAxis.categories.push title
                    options.series = [{name: facet.title, data: (parseInt(cat.count) for cat in data)}]
                    @$("#stats-container-#{index}").highcharts(options)
        @jsloaded = true


class app.QueryView extends Backbone.View

    template: Handlebars.compile """
        {{#eachCollapse query}}
            <span style="margin:15px">
                <a href="#" data-action='removeFromQuery' data-predicate="{{@key}}" data-uri="{{uri}}">[x]</a>
                {{@key}}:
                <a href="#" data-action='replaceQuery' data-predicate="{{@key}}" data-uri="{{uri}}">
                    {{title}}
                </a>
            </span>
        {{/eachCollapse}}
    """

    initialize: () ->
        @listenTo @model, 'change', @render
        @listenTo @model, 'clear', @render

    render: ()->
        @$el.html @template {query: @model.attributes}
        @.trigger 'rendered'


class app.TotalCountView extends Backbone.View

    template: Handlebars.compile """
        <h6>
            {{#loading}}loading{{/loading}}
            <span id="totalCount">{{total}}</span>
            results
        </h6>
    """

    initialize: ()->
        @listenTo @model, 'change', @render

    render: ()->
        @$el.html @template @model.attributes
        @.trigger 'rendered'


class app.AppView extends Backbone.View
    ###
    model is the query. Passed by the router.
    ###

    el: '#layout'
    template: Handlebars.compile """
        <h2>{{capitalize type}}</h2>

        <div id="query" style="margin-bottom: 30px"></div>

        <div class="row">
            <div class="small-9 columns">
                <dl class="sub-nav">
                  <dt>View as:</dt>
                  <dd class="{{isActive format 'documents'}}"><a href="#" data-action="switchformat" data-viewformat="documents">documents</a></dd>
                  <dd class="{{isActive format 'stats'}}"><a href="#" data-action="switchformat" data-viewformat="stats">stats</a></dd>
                </dl>
             </div>
             <div class="small-3 columns text-right" id="totalCount"></div>
        </div>

         <div class="row">
            <div class="small-12 columns" id="content"></div>
        </div>
    """

    events: {
        'click [data-action=switchformat]': 'switchFormat'
        'click [data-action=addToQuery]': 'addToQuery'
        'click [data-action=removeFromQuery]': 'removeFromQuery'
        'click [data-action=replaceQuery]': 'replaceQuery'
        'click [data-action=showMore]': 'showMore'
    }

    initialize: () ->
        @listenTo @model, 'change', @render
        @listenTo @model, 'change', @updateUrl

        @nbLoadingFinished = 0
        @listenTo @model.documents, 'reset', @loadingFinished
        @listenTo @model.facets, 'reset', @loadingFinished

        @queryView = new app.QueryView({model: @model.query})
        @listenTo @queryView, 'rendered', @renderQuery

        @facetsView = new app.FacetsView({collection: @model.facets})
        @listenTo @facetsView, 'rendered', @renderFacets

        @totalCountView = new app.TotalCountView({model: @model.count})
        @listenTo @totalCountView, 'rendered', @renderTotalCount

        @documentsView = new app.DocumentsView({collection: @model.documents})
        @listenTo @documentsView, 'rendered', @renderContent
        @statsView = new app.StatsView({collection: @model.facets})
        @listenTo @statsView, 'rendered', @renderContent

    render: (evt) ->
        @$('#main').html @template {
            type: @model.get('type')
            format: @model.get('format')
        }
        @renderQuery()
        @renderTotalCount()
        @renderContent()

    renderContent: (view)->
        if @model.get('format') is 'documents' and (view?.name is 'documentsview' or not view)
            $('#content').html @documentsView.el
        else if @model.get('format') is 'stats' and (view?.name is 'statsview' or not view)
            $('#content').html @statsView.el
            if @statsView.collection.length and not @statsView.jsloaded
                @statsView.loadJS()

    renderQuery: () ->
        $('#query').html @queryView.el

    renderFacets: () ->
        $('#facets').html @facetsView.el

    renderTotalCount: () ->
        $('#totalCount').html @totalCountView.el

    loadingFinished: (item) ->
        @nbLoadingFinished += 1
        if @nbLoadingFinished is 2
            @model.count.set 'loading', false
            @nbLoadingFinished = 0

    ###
    actions
    ###
    switchFormat: (ev) ->
        ev.preventDefault()
        format = ev.target.dataset.viewformat
        @model.set 'format', format

    addToQuery: (ev)->
        ev.preventDefault()
        data = ev.target.dataset
        @model.addToQuery data.predicate, data.uri

    removeFromQuery: (ev)->
        ev.preventDefault()
        data = ev.target.dataset
        @model.removeFromQuery data.predicate, data.uri

    replaceQuery: (ev) ->
        ev.preventDefault()
        data = ev.target.dataset
        @model.replaceQuery data.predicate, data.uri

    updateUrl: () ->
        type = @model.get 'type'
        query = @model.get 'queryString'
        format = @model.get 'format'
        Backbone.history.navigate("#{type}/#{format}#{query}")

    showMore: (ev) ->
        ev.preventDefault()
        classTarget = ev.target.dataset.infoTarget or 'moreinfo'
        $morelink = $(ev.target)
        $infoContainer = $morelink.closest('[data-toggleinfo]').find(".#{classTarget}")
        $infoContainer.toggle(400)
        newLabel = $infoContainer.attr('data-info-toggle-label') or 'hide'
        $infoContainer.attr('data-info-toggle-label', $morelink.text())
        $morelink.text(newLabel)

class app.Router extends Backbone.Router

    routes:
        ':type/:format?*query':     'explore'
        ':type/:format':            'explore'
        ':type':                    'explore'
        '':                         'index'

    initialize: () ->
        @control = new app.Control()
        @appview = new app.AppView({model: @control})

    index: () ->
        Backbone.history.navigate("#team/documents", true)

    explore: (type, format, query) ->
        if not format
            format = 'documents'
        params = {}
        if query
            for param in query.split('&')
                [key, value] = param.split('=')
                unless params[key]?
                    params[key] = []
                params[key].push value
        @control.changeFormat(format)
        @control.fetch(type, params)


$ ->
    new app.Router()
    Backbone.history.start()
