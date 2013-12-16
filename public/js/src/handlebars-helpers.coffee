
handlebarsHelpers =
	'capitalize': (input, options) ->
		_.str.capitalize input

	'classify': (input, options) ->
		_.str.classify input.toLowerCase()

	'isActive': (context, value, options) ->
		ret = ''
		if context is value
			ret = 'active'
		ret

	'isArray': (input, options) ->
		if _.isArray input
			options.fn(@)
		else
			options.inverse(@)

	'eachAsArray': (context, options) ->
		ret = ''
		if context
			if _.isObject(context) and not _.isArray(context)
				context = [context]
			if context.length > 0
				for value in context
					ret += options.fn value
			else
				return options.inverse(@)
		else
			return options.inverse(@)
		ret

	'eachArrays': (context, options) ->
		ret = ''
		for key, value of context
			if _.isArray value
				ret = ret + options.fn value, {data: {key: key}}
		ret

	'eachLiterals': (context, options) ->
		ret = ''
		for key, value of context
			unless _.isArray value
				ret = ret + options.fn value, {data: {key: key}}
		ret

	'eachFacetRelations': (context, options) ->
		ret = ''
		for facet in context when facet.facets.length and not facet.stats.avg?
			ret = ret + options.fn facet
		ret

	'eachFacetStats': (context, options) ->
		ret = ''
		for facet in context when facet.stats.avg?
			ret = ret + options.fn facet
		ret

	'ifFacetRelations': (context, options) ->
		rels = (1 for facet in context when not facet.stats.avg?)
		if rels.length
			options.fn(@)
		else
			options.inverse(@)

	'ifFacetStats': (context, options) ->
		rels = (1 for facet in context when facet.stats.avg?)
		if rels.length
			options.fn(@)
		else
			options.inverse(@)

	'eachCollapse': (context, options) ->
		ret = ''
		for key, value of context
			if _.isArray value
				for val in value
					ret = ret + options.fn val, {data: {key: key}}
			else
				ret = ret + options.fn value, {data: {key: key}}
		ret

	'eachSlice': (context, start, end, options) ->
		ret = ''
		if context
			if not _.isArray context
				context = [context]
			if context[start...end].length
				for item in context[start...end]
					ret += options.fn item
			else
				return options.inverse(@)
		else
			return options.inverse(@)
		ret

	'ifEqual': (context, value, options) ->
		if context is value
			options.fn(@)
		else
			options.inverse(@)

	'displayFacet': (context, options) ->
		if context.facets.length > 1
			options.fn(@)
		else
			options.inverse(@)

	'ifLength': (context, op, value, options) ->
		if context
			if op in ['eq', '='] and context.length is value
				options.fn(@)
			else if op in ['lt', '<'] and context.length < value
				options.fn(@)
			else if op in ['gt', '>'] and context.length > value
				options.fn(@)
			else
				options.inverse(@)

	'gt': (context, value, options) ->
		if context > value
			options.fn(@)
		else
			options.inverse(@)

	'uri2pubmed': (context, options) ->
		if context
			pmid = context.split('/')[-1..]
			return "http://www.ncbi.nlm.nih.gov/pubmed/#{pmid}"
		
	'tojson': (context, options) ->
		if context
			return JSON.stringify context


for helperName, helper of handlebarsHelpers
	Handlebars.registerHelper helperName, helper
