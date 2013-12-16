
JVectorByName =
	Alsace:	
		id: 'FR-A'
		postcodes: ['67', '68']
	Aquitaine: 
		id: 'FR-B'
		postcodes: ['24', '33', '40', '47', '64']
	Auvergne: 
		id: 'FR-C'
		postcodes: ['03', '15', '43', '63']
	'Basse-Normandie': 
		id: 'FR-P'
		postcodes: ['14', '50', '61']
	Bourgogne: 
		id: 'FR-D'
		postcodes: ['21', '58', '71', '89']
	Bretagne:
		id: 'FR-E'
		postcodes: ['29', '22', '56', '35']
	Centre: 
		id: 'FR-F'
		postcodes: ['18', '28', '36', '37', '41', '45']
	'Champagne-Ardenne': 
		id: 'FR-G'
		postcodes: ['08', '10', '51', '52']
	Corse: 
		id: 'FR-H'
		postcodes: ['2A', '2B']
	'Franche-Comté':
		id: 'FR-I'
		postcodes: ['25', '39', '70', '90']
	'Haute-Normandie': 
		id: 'FR-Q'
		postcodes: ['27', '76']
	'Île de France': 
		id: 'FR-J'
		postcodes: ['75', '91', '92', '93', '77', '94', '95', '78']
	'Languedoc-Roussillon':
		id: 'FR-K'
		postcodes: ['11', '30', '34', '48', '66']
	Limousin: 
		id: 'FR-L'
		postcodes: ['19', '23', '87']
	Lorraine: 
		id: 'FR-M'
		postcodes: ['54', '55', '57', '88']
	'Midi-Pyrénées': 
		id: 'FR-N'
		postcodes: ['09', '12', '31', '32', '46', '65', '81', '82']
	'Nord - Pas-de-Calais': 
		id: 'FR-O'
		postcodes: ['59', '62']
	'Pays de la Loire': 
		id: 'FR-R'
		postcodes: ['44', '49', '53', '72', '85']
	Picardie: 
		id: 'FR-S'
		postcodes: ['02', '60', '80']
	'Poitou-Charentes': 
		id: 'FR-T'
		postcodes: ['16', '17', '79', '86']
	"Provence-Alpes-Côte d'Azur": 
		id: 'FR-U'
		postcodes: ['04', '05', '06', '13', '83', '84']
	'Rhône-Alpes': 
		id: 'FR-V'
		postcodes: ['01', '07', '26', '38', '42', '69', '73', '74']
	Gaudeloupe: 
		id: 'FR-GP'
		postcodes: ['971']
	Guyane: 
		id: 'FR-GF'
		postcodes: ['973']
	Martinique: 
		id: 'FR-MQ'
		postcodes: ['972']
	Mayotte: 
		id: 'FR-YT'
		postcodes: ['976']
	'La Réunion': 
		id: 'FR-RE'
		postcodes: ['974']


JVectorByCode = {}

for name, value of JVectorByName
	for postcode in value.postcodes
		JVectorByCode[postcode] = {id: value.id, name: name}