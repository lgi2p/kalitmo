
class RDFInstance
    constructor: (attrs, @classObject) ->
        @baseURI = @classObject.baseURI
        @typeURI = @classObject.typeURI
        @typeTitle = @classObject.typeTitle or @typeURI
        @propertyURI = @classObject.propertyURI

        unless attrs.id
            console.log attrs, @classObject
            throw "id not found"
        @id = attrs.id
        @idURI = "#{@baseURI}/#{@id}"
        @title = attrs.title or @id
        @relations = []   
        @properties = []

    stringify: () ->
        results = [
            @classObject.stringify()
            "<#{@idURI}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#{@typeURI}> ."
            "<#{@idURI}>  <http://purl.org/dc/elements/1.1/title>  \"#{@title}\" ."
        ]
        for relation in @relations
            if relation.propertyURI
                results.push "<#{@idURI}> <#{relation.propertyURI}> <#{relation.idURI}> ."
            results.push relation.stringify()
        for property in @properties
            if property.value
                format = ''
                if property.format
                    format = "^^xsd:#{property.format}"
                results.push "<#{@idURI}> <#{property.uri}> \"#{property.value}\"#{format} ."
                results.push property.stringify()
        return (i for i in results when i).join('\n')

    addRelation: (relation) ->
        @relations.push relation

    addProperty: (property) ->
        @properties.push property


exports.RDFClass = class RDFClass
    constructor: (config) ->
        throw 'baseURI not found' unless config.baseURI
        throw 'type.uri not found' unless config.type.uri
        @baseURI = config.baseURI
        @typeURI = config.type.uri
        @typeTitle = config.type.title or @typeURI

        if config.property
            @propertyURI = config.property.uri
            @propertyTitle = config.property.title or @propertyURI
        @stringified = false

    new: (attrs) ->
        return new RDFInstance(attrs, @)

    stringify: () ->
        if not @stringified
            @stringified = true
            results = [
                "<#{@typeURI}> <http://purl.org/dc/elements/1.1/title> \"#{@typeTitle}\" ."
            ]
            if @propertyURI
                results.push "<#{@propertyURI}> <http://purl.org/dc/elements/1.1/title> \"#{@propertyTitle}\" ."
            return results.join('\n')
        return ''


class RDFLiteral
    constructor: (@value, @property) ->
        {@uri, @format, @title} = @property

    stringify: () ->
        return @property.stringify()


exports.RDFProperty = class RDFProperty
    constructor: (config) ->
        throw 'uri not found' unless config.uri
        @uri = config.uri
        @title = config.title or @uri
        @format = config.format

    new: (value) ->
        return new RDFLiteral(value, @)

    stringify: () ->
        if not @stringified
            @stringified = true
            return "<#{@uri}> <http://purl.org/dc/elements/1.1/title> \"#{@title}\" ."
        return ''

exports.rdfParser = {
    classes: {
        team: new RDFClass({
            baseURI: 'http://kalitmo.org/team'
            type: {
                uri: 'http://kalitmo.org/type/Team'
                title: 'team'
            }
        })

        county: new RDFClass({
            baseURI: 'http://kalitmo.org/county'
            type: {
                uri: 'http://kalitmo.org/type/County'
                title: 'county'
            }
            property: {
                uri: 'http://kalitmo.org/property/county'
                title: 'county'
            }
        })

        leader: new RDFClass({
            baseURI: 'http://kalitmo.org/leader'
            type: {
                uri: 'http://kalitmo.org/type/Leader'
                title: 'leader'
            }
            property: {
                uri: 'http://kalitmo.org/property/leader'
                title: 'leader'
            }
        })

        affiliation: new RDFClass({
            baseURI: 'http://kalitmo.org/organism'
            type: {
                uri: 'http://kalitmo.org/type/Organism'
                title: 'organism'
            }
            property: {
                uri: 'http://kalitmo.org/property/affiliated_to'
                title: 'affiliated to'
            }
        })

        mainItmo:  new RDFClass({
            baseURI: 'http://kalitmo.org/itmo'
            type: {
                uri: 'http://kalitmo.org/type/Itmo'
                title: 'itmo'
            }
            property: {
                uri: 'http://kalitmo.org/property/main_itmo'
                title: 'ITMO'
            }
        })

        secondaryItmo: new RDFClass({
            baseURI: 'http://kalitmo.org/itmo'
            type: {
                uri: 'http://kalitmo.org/type/Itmo'
                title: 'itmo'
            }
            property: {
                uri: 'http://kalitmo.org/property/secondary_itmo'
                title: 'ITMO'
            }
        })

        keyword: new RDFClass({
            baseURI: 'http://kalitmo.org/keyword'
            type: {
                uri: 'http://kalitmo.org/type/Keyword'
                title: 'keyword'
            }
            property: {
                uri: 'http://kalitmo.org/property/keyword'
                title: 'keyword'
            }
        })

        methodological: new RDFClass({
            baseURI: 'http://kalitmo.org/methodological'
            type: {
                uri: 'http://kalitmo.org/type/Methodological'
                title: 'methodological'
            }
            property: {
                uri: 'http://kalitmo.org/property/methodological'
                title: 'methodological'
            }
        })

        bioResource: new RDFClass({
            baseURI: 'http://kalitmo.org/bio_resource'
            type: {
                uri: 'http://kalitmo.org/type/BioResource'
                title: 'bio resource'
            }
            property: {
                uri: 'http://kalitmo.org/property/bio_resource'
                title: 'bio resource'
            }
        })

        publication: new RDFClass({
            baseURI: 'http://kalitmo.org/publication'
            type: {
                uri: 'http://kalitmo.org/type/Publication'
                title: 'publication'
            }
            property: {
                uri: 'http://kalitmo.org/property/published'
                title: 'published'
            }
        })

        meshConcept: new RDFClass({
            baseURI: 'http://kalitmo.org/mesh_concept'
            type: {
                uri: 'http://kalitmo.org/type/MeshConcept'
                title: 'mesh concept'
            }
            property: {
                uri: 'http://kalitmo.org/property/mesh_concept'
                title: 'concept'
            }
        })

        author: new RDFClass({
            baseURI: 'http://kalitmo.org/author'
            type: {
                uri: 'http://kalitmo.org/type/Author'
                title: 'author'
            }
            property: {
                uri: 'http://kalitmo.org/property/author'
                title: 'author'
            }
        })

        language: new RDFClass({
            baseURI: 'http://kalitmo.org/language'
            type: {
                uri: 'http://kalitmo.org/type/Language'
                title: 'language'
            }
            property: {
                uri: 'http://kalitmo.org/property/language'
                title: 'language'
            }
        })

        publishingYear: new RDFClass({
            baseURI: 'http://kalitmo.org/publishing_year'
            type: {
                uri: 'http://kalitmo.org/type/PublishingYear'
                title: 'publishing year'
            }
            property: {
                uri: 'http://kalitmo.org/property/publishing_year'
                title: 'published in'
            }
        })
    }
    properties: {

        nbResearchers: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_researchers'
            title: 'researchers'
            format: 'integer'
        })

        nbTechnicians: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_technicians'
            title: 'technicians'
            format: 'integer'
        })

        nbPostdocs: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_postdocs'
            title: 'postdocs'
            format: 'integer'
        })

        nbPhds: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_phds'
            title: 'PHDs'
            format: 'integer'
        })

        nbPatents: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_patents'
            title: 'patents'
            format: 'integer'
        })

        nbResearchGrants: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_research_grants'
            title: 'research grants'
            format: 'integer'
        })

        nbIndustrialPartnerships: new RDFProperty({
            uri: 'http://kalitmo.org/property/nb_industrial_partnerships'
            title: 'industrial partnerships'
            format: 'integer'
        })
    }
}