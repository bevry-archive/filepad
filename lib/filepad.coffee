# Requires
fs = require 'fs'
path = require 'path'
express = require 'express'
now = require 'now'
nowpad = require 'nowpad'
coffee4clients = require 'coffee4clients'
watchTree = require 'watch-tree'
util = require 'bal-util'
coffee = require 'coffee-script'

# Filepad
class Filepad

	# Server
	server: null
	everyone: null
	nowpad: null
	port: 9573
	filePath: process.cwd()
	publicPath: __dirname+'/public'

	# Filepad
	files: null

	# Initialise
	constructor: ({path,port}={}) ->
		# Prepare
		@filePath = path || process.argv[2] || @filePath
		@port = port || @port

		# Clean
		@files = 
			slugsToFullPath: {}
			slugsToRelativePath: {}
			tree: {}
			slugsToValue: {}

		# Correct
		if @filePath.substring(0,1) is '.'
			@filePath = process.cwd() + '/' + @filePath
	
		# Check
		fs.realpath @filePath, (err) =>
			throw err
		
		# Create Server
		@server = express.createServer()

		# Configure Server
		@server.configure =>
			# Standard
			@server.use express.errorHandler()
			@server.use express.bodyParser()
			@server.use express.methodOverride()

			# Routing
			@server.use @server.router
			@server.use express.static @publicPath

			# Now.js
			@everyone = now.initialize @server, clientWrite: false

			# Nowpad
			@nowpad = nowpad.createInstance(
				server: @server
				everyone: @everyone
			)

			# Coffee4Clients
			coffee4clients.createInstance {
				server: @server
				publicPath: @publicPath
			}
		
		# Init Server
		@server.listen @port
		console.log 'Express server listening on port %d', @server.address().port

		# File Center then Communication Center
		@fileCenter => @comCenter()
	
	# Establish a File Center
	fileCenter: (next) ->
		filepad = @

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
		watcher = watchTree.watchTree(@filePath)
		
		# File Deleted
		watcher.on 'fileDeleted', (fileFullPath) ->
			# Remove from files
			slug = filepad.delFile fileFullPath
			# Broadcast files
			filepad.broadcastFiles()
		
		# File Created
		watcher.on 'fileCreated', (fileFullPath,stat) ->
			# Add to files
			slug = filepad.addFile fileFullPath
			# Broadcast files
			filepad.broadcastFiles()

		# Fire when a change syncs to the server
		@nowpad.bind 'sync', (fileId,value) ->
			filepad.files.slugsToValue[fileId] = value
	
	# Add a file
	addFile: (fileFullPath) ->
		filepad = @

		# Fetch
		fileRelativePath = fileFullPath.replace(@filePath,'').replace(/^\/+/,'')
		fileSlug = util.generateSlugSync fileRelativePath
	
		# Check
		if @files.slugsToFullPath[fileSlug]
			return # Nothing to do
	
		# Add to Objects
		@files.slugsToFullPath[fileSlug] = fileFullPath
		@files.slugsToRelativePath[fileSlug] = fileRelativePath

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
		fs.readFile fileFullPath, (err,data) =>
			throw err if err
			value = data.toString()
			filepad.files.slugsToValue[fileSlug] = value
			@nowpad.addDocument fileSlug, value
		
		# Return
		return fileSlug

	# Delete file
	delFile: (fileFullPath) ->
		# Fetch
		fileRelativePath = fileFullPath.replace(@filePath,'').replace(/^\/+/,'')
		fileSlug = util.generateSlugSync fileRelativePath

		# Check
		if not @files.slugsToFullPath[fileSlug]
			return # Nothing to do

		# Delete from Object
		delete @files.slugsToFullPath[fileSlug]
		delete @files.slugsToRelativePath[fileSlug]

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
		@nowpad.delDocument fileSlug
		
		# Return
		return fileSlug
	
	# Broadcast the list of files to all clients
	broadcastFiles: ->
		@everyone.now.filepad_notifyList false, {slugsToPath: @files.slugsToRelativePath, tree: @files.tree} if @everyone.now.filepad_notifyList

	# Establish Communication Center between Client and Server
	comCenter: ->
		filepad = @
		everyone = @everyone
		
		# A client has connected
		everyone.connected ->

		# A client has disconnected
		everyone.disconnected ->

		# A client is shaking hands with the server
		# next(err,files)
		everyone.now.filepad_handshake = (notifyList,next) ->
			# Check
			if (typeof notifyList isnt 'function') or (typeof next isnt 'function')
				next new Error 'Invalid arguments'
			
			# Apply
			@now.filepad_notifyList = notifyList

			# Return a list of files
			next false, {paths: filepad.files.slugsToRelativePath, tree: filepad.files.tree}
		
		# Create a a new file
		# next(err,slug,fileRelativePath)
		everyone.now.filepad_newFile = (fileRelativePath,next) ->
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
		everyone.now.filepad_delFile = (fileRelativePath,next) ->
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
		
		# Save a file
		# next(err)
		everyone.now.filepad_saveFile = (fileId,next) ->
			fileFullPath = filepad.files.slugsToFullPath[fileId]
			value = filepad.files.slugsToValue[fileId]
			# Check
			unless fileFullPath
				throw new Error 'Could not find the file with id '+fileId
			# Success
			fs.writeFile fileFullPath, value, (err) ->
				throw err if err
				next false

		# Revert a file
		# next(err)
		everyone.now.filepad_revertFile = (fileId,next) ->
			# Read the local file
			# Submit the patch to nowpad
			# Clients will be synced
			throw new Error 'not yet implemented'

# API
filepad =
	createInstance: (config) ->
		return new Filepad(config)

# Export
module.exports = filepad
