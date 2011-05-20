# FilePad

FilePad is a file browser and editor built with node.js, coffeecript and nowpad


## Installing


1. [Install Node.js](https://github.com/balupton/node/wiki/Installing-Node.js)

2. Install CoffeeScript
		
		npm -g install coffee-script

3. Install FilePad

		npm -g install filepad


## Using

1. Start filepad

	filepad

2. Open http://localhost:9573/ in your browser


## Implementing

- With Node.js in JavaScript

	``` javascript
	// Include FilePad
	require('coffee-script');
	filepad = require('filepad');

	// Initialise the FilePad Server
	filepad.setup(pathToEdit,options);
	```

- With Node.js in CoffeeScript
	
	``` coffeescript
	# Include FilePad
	filepad = require 'filepad'

	# Initialise the FilePad Server
	filepad.setup pathToEdit, options


## History

- v0.3 May 20, 2011
	- Now supports multiple filepad isntances

- v0.2 May 19, 2011
	- Got file saving going
	- Got file listings refreshing when files are added or deleted
	- Added a login modal for the future

- v0.1 May 18, 2011
	- Initial commit


## License

Licensed under the [MIT License](http://creativecommons.org/licenses/MIT/)
Copyright 2011 [Benjamin Arthur Lupton](http://balupton.com)
