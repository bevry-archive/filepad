# Requires
fs = require 'fs'
path = require 'path'
express = require 'express'
now = require 'now'
nowpad = require 'nowpad'
coffee4clients = require 'coffee4clients'
watch = require 'watch'
util = require 'bal-util'
coffee = require 'coffee-script'

# -------------------------------------
# Server

filepad =
	# Server
	app: null
	everyone: null
	filePath: process.cwd()
	publicPath: __dirname+'/public'

	# Filepad
	files:
		slugToPath: {}
		slugs: {}
		tree: {}

	# Initialise
	init: ->
		# File Path
		if process.argv[2]
			@filePath = process.argv[2]
			if @filePath.substring(0,1) is '.'
				@filePath = process.cwd() + '/' + @filePath
		fs.realpath @filePath, (err,@filePath) =>
			@initServer()
	
	# Init Server
	initServer: ->
		# Create Server
		@app = express.createServer()

		# Configure Server
		@app.configure =>
			# Standard
			@app.use express.errorHandler()
			@app.use express.bodyParser()
			@app.use express.methodOverride()

			# Routing
			@app.use @app.router
			@app.use express.static @publicPath

			# Now.js
			@everyone = now.initialize @app, clientWrite: false

			# Nowpad
			nowpad.setup @app, @everyone

			# Coffee4Clients
			coffee4clients.setup @app, @publicPath

		# Init Server
		@app.listen(9573);
		console.log 'Express server listening on port %d', @app.address().port

		# File Center then Communication Center
		@fileCenter => @comCenter()
	
	# Establish a File Center
	fileCenter: (next) ->
		# Scan the directory for files
		util.scandir(
			# Path
			@filePath

			# File Action
			(fileFullPath,fileRelativePath,next) ->
				# Add file
				filepad.addFile fileFullPath

				# Continue
				next()
			
			# Dir Action
			false

			# Complete
			(err) ->
				# Error
				throw err if err
				# Success
				filepad.broadcastFiles()
				# Next
				next()
		)

		# Setup up watches for the files
		watch.createMonitor @filePath, (monitor) =>
			# File Changed
			# monitor.on 'changed', (fileFullPath,newStat,oldStat) ->
			#	DocPad.generate()
			
			# File Created
			monitor.on 'created', (fileFullPath,stat) ->
				# Add to files
				slug = filepad.addFile fileFullPath
				# Broadcast files
				filepad.broadcastFiles()
			
			# File Deleted
			monitor.on 'removed', (fileFullPath,stat) ->
				# Remove from files
				slug = filepad.delFile fileFullPath
				# Broadcast files
				filepad.broadcastFiles()
		
		# Fire when a change syncs to the server
		nowpad.bind 'sync', (documentId,value) ->
			fileFullPath = filepad.files.slugToPath[documentId]
			# Check
			unless fileFullPath
				throw new Error 'Could not find the file with slug '+documentId
			# Success
			fs.writefile fileFullPath, value, (err) ->
				throw err if err
	
	# Add a file
	addFile: (fileFullPath) ->
		# Fetch
		fileRelativePath = fileFullPath.replace(@filePath,'').replace(/^\/+/,'')
		fileSlug = util.generateSlugSync fileRelativePath
	
		# Check
		if @files.slugToPath[fileSlug]
			return # Nothing to do
	
		# Add to Objects
		@files.slugToPath[fileSlug] = fileFullPath
		@files.slugs[fileSlug] = true

		# Add to Tree
		fileTree = path.dirname(fileRelativePath).split '/'
		fileParent = @files.tree
		for dir in fileTree
			if not dir or dir is '.'
				continue
			if not fileParent[dir]
				fileParent[dir] = {}
			fileParent = fileParent[dir]
		fileParent[path.basename(fileRelativePath)] = fileSlug

		# Add to nowpad
		fs.readFile fileFullPath, (err,data) ->
			throw err if err
			value = data.toString()
			nowpad.addDocument fileSlug, value
		
		# Return
		return fileSlug

	# Delete file
	delFile: (fileFullPath) ->
		# Fetch
		fileRelativePath = fileFullPath.replace(@filePath,'').replace(/^\/+/,'')
		fileSlug = util.generateSlugSync fileRelativePath

		# Check
		if not @files.slugToPath[fileSlug]
			return # Nothing to do

		# Delete from Object
		delete @files.slugToPath[fileSlug]
		delete @files.slugs[fileSlug]

		# Delete from Tree
		fileTree = path.dirname(fileRelativePath).split '/'
		fileParent = @files.tree
		for dir in fileTree
			if not dir or dir is '.'
				continue
			if not fileParent[dir]
				fileParent[dir] = {}
			fileParent = fileParent[dir]
		delete fileParent[path.basename(fileRelativePath)]

		# Remove from nowpad
		nowpad.delDocument fileSlug
		
		# Return
		return fileSlug
	
	# Broadcast the list of files to all clients
	broadcastFiles: ->
		@everyone.now.notifyFiles {slugs: @files.slugs, tree: @files.tree} if @everyone.now.notifyFiles

	# Establish Communication Center between Client and Server
	comCenter: ->
		everyone = @everyone
		
		# A client has connected
		everyone.connected ->

		# A client has disconnected
		everyone.disconnected ->

		# A client is shaking hands with the server
		# next(err,files)
		everyone.now.handshake = (notifyList,next) ->
			# Check
			if (typeof notifyList isnt 'function') or (typeof next isnt 'function')
				next new Error 'Invalid arguments'
			
			# Apply
			@now.notifyList = notifyList

			# Return a list of files
			next false, {slugs: filepad.files.slugs, tree: filepad.files.tree}
		
		# Create a a new file
		# next(err,slug,fileRelativePath)
		everyone.now.newFile = (fileRelativePath,next) ->
			fileFullPath = filepad.filePath + '/' + fileRelativePath.replace(/^\/+/,'')
			util.resolvePath fileFullPath, (err,fileFullPath,fileRelativePath) ->
				if err then return next err
				# Ensure Path
				slug = util.generateSlugSync fileRelativePath
				util.ensurePath path.dirname(fileFullPath), (err) ->
					if err then return next err
					# Write File
					fs.writeFile fileFullPath, '', (err) ->
						if err then return next err 
						# Success
						filepad.addFile fileFullPath
						next false, slug, fileRelativePath

		# Delete an existing file
		# next(err,slug,fileRelativePath)
		everyone.now.delFile = (fileRelativePath,next) ->
			fileFullPath = filepad.filePath + '/' + fileRelativePath.replace(/^\/+/,'')
			util.resolvePath fileFullPath, (err,fileFullPath,fileRelativePath) ->
				if err then return next err
				# Delete File
				slug = util.generateSlugSync fileRelativePath
				fs.unlink fileFullPath, (err) ->
					if err then return next err
					# Success
					filepad.delFile fileFullPath
					next false, slug, fileRelativePath


# Initialise
filepad.init()

# Export
module.exports = filepad
