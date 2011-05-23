((window)->
	# Globals
	$ = jQuery = window.jQuery
	console = window.console
	nowpad = window.nowpad

	# Filepad
	filepad =

		# Variables
		files:
			paths: {}
			tree: {}
		extsToMode:
			c: 'c_cpp'
			cpp: 'cpp'
			coffee: 'coffee'
			cs: 'csharp'
			css: 'css'
			html: 'html'
			java: 'java'
			js: 'javascript'
			json: 'javascript'
			pl: 'perl'
			php: 'php'
			py: 'python'
			rb: 'ruby'
			svg: 'svg'
			xml: 'xml'
		editors: {}
		contentHeight: 0
		contentWidth: 0
		
		# Elements
		$sidebar: null
		$main: null
		$mainTabs: null
		$mainPanels: null
		$mainActions: null
		$mainStatus: null
		$files: null
	
		# Initialise
		init: -> $ =>
			# Elements
			@$login = $ '#login'
			@$overlay = $ '#overlay'
			@$sidebar = $ '#sidebar'
			@$main = $ '#main'
			@$mainTabs = @$main.children '.tabs:first'
			@$mainPanels = @$main.children '.panels:first'
			@$mainActions = @$main.children '.actions:first'
			@$mainStatus = @$mainActions.find '.action-status:first'
			@$files = $ '#files'


			# Resize
			$window = $(window)
			$window.resize =>
				windowHeight = $window.height()
				windowWidth = $window.width()
				@$main.add(@$sidebar).height windowHeight

				@contentHeight = windowHeight - 30
				@contentWidth = windowWidth - 220

				$('.panels').height @contentHeight
				$('.editable,.ace').height(@contentHeight).width(@contentWidth)

				for own key, editor of @editors
					editor.resize()


			$window.trigger 'resize'

			# Server Timeout
			timeoutCallback = ->
				throw new Error 'Could not connect to the server'
			timeout = window.setTimeout timeoutCallback, 1500

			# Server
			window.now.ready ->
				# Clean
				clearTimeout timeout
				filepad.$login.add(filepad.$overlay).fadeOut(500)

				# Handshake
				window.now.filepad_handshake(
					# Notify List
					(err,files) ->
						# Handle
						if err
							throw err
						else if files
							filepad.refreshFiles files
					
					# Callback
					(err,files) ->
						# Clean
						filepad.$mainTabs.empty()
						filepad.$mainPanels.empty()

						# Handle
						if err
							throw err
						else if files
							filepad.refreshFiles files
				)

			# Files
			@$files.find('li.dir').live 'click', (event) ->
				$dir = $(this)
				event.stopPropagation()
				$dir.toggleClass('open')
			@$files.find('li.file').live 'click', (event) ->
				$file = $(this)
				event.stopPropagation()
				filepad.editFile $file.attr 'for'

			# Sidebar Tabs
			$('#sidebar .tab').live 'click', (event) ->
				# Fetch
				$tab = $(this)
				id = $tab.attr 'for'
				$panel = $ '#'+id

				# Active
				$tab.addClass('active').siblings().removeClass 'active'
				if $panel.length isnt 0
					$panel.addClass('active').siblings().removeClass 'active'
			
			# Main Tabs
			$('#main .tab').live 'click', (event) ->
				# Select
				filepad.selectFile $(this).attr 'for'
			
			# Save + Revert Actions
			$(document).keydown (event) ->
				console.log event.which
				# ctrl+s
				if event.ctrlKey and event.which is 83
					event.preventDefault()
					filepad.saveAction()
				# ctrl+alt+w
				if event.ctrlKey and event.which is 87
					event.preventDefault()
					filepad.closeFile()
				# ctrl+alt+r
				if event.ctrlKey and event.altKey and event.which is 82 
					event.preventDefault()
					filepad.revertAction()
			$('#main-save').click (event) ->
				filepad.saveAction()
			$('#main-revert').click (event) ->
				filepad.revertAction()
			
		# Save Action
		saveAction: ->
			fileId = @activeFile()
			if fileId
				@$mainStatus.attr 'title', @$mainStatus.text()
				@$mainStatus.text 'Saving...'
				doneSaving = =>
					@$mainStatus.text @$mainStatus.attr 'title'
				timeout = window.setTimeout(
					=>
						alert 'save timed out'
						doneSaving()
					5000
				)
				window.now.filepad_saveFile fileId, ->
					clearTimeout timeout
					window.setTimeout doneSaving, 1500
		
		# Revert Action
		revertAction: ->
			alert('revert')
		
		# Refresh File Tree
		refreshFileTree: (files) ->
			$files = @$files

			$tree = $ '<nav class="tree files" />'
			$files.append $tree

			generateFiles = (files,$files) ->
				for own fileName, fileValue of files
					# File
					if fileValue.charAt
						$file = $ '<li class="file" for="'+fileValue+'"><span>'+fileName+'</span></li>'
						$files.append $file
					# Directory
					else
						$dir = $ '<li class="dir"><span>'+fileName+'</span><nav></nav></li>'
						$files.append $dir
						generateFiles fileValue, $dir.children('nav')
				
				# End
				return

			generateFiles files, $tree
			
			# End
			return
		
		# Storage
		store: (data) ->
			result = {}
			name = 'filepad'
			
			if window.localStorage and window.JSON
				if data
					try
						result = JSON.parse localStorage.getItem name
				else
					try
						localStorage.setItem name, JSON.stringify data
						result = data
				
			return result

		# Refresh Files
		refreshFiles: (files) ->
			# Clean
			@$files.empty()

			# Apply
			@files = files

			# Cache
			$main = @$main

			# Refresh file tree
			@refreshFileTree files.tree

			# Fetch open documents
			$pads = $main.find '> .panels > .panel'

			# Check local storage
			if $pads.length is 0
				data = @store
				if data and data.files and data.files.length
					for file in data.files
						@editFile file

			# Ensure that any open documents actually still exist
			$pads.each ->
				# Fetch
				$pad = $ this
				id = $pad.attr('id')
				slug = id.replace(/^file\-/,'')

				# Exists?
				if files.paths[slug]
					# Keep
				else
					# Remove
					filepad.closeFile slug
				
				# End
				return
			
			# End
			return
		
		# Fetch Path
		getPath: (fileId) ->
			return @files.paths[fileId]
		
		# Fetch Tab
		getTab: (fileId) ->
			return @$mainTabs.find '.tab[for='+fileId+']'
		
		# Fetch Panel
		getPanel: (fileId) ->
			return @$mainPanels.find '.panel[for='+fileId+']'
		
		# Editing File
		editingFile: (fileId) ->
			return @getTab(fileId).length isnt 0
		
		# Fetch Active File
		activeFile: (fileId) ->
			if fileId
				return @activeFile() is fileId
			else
				return @$mainTabs.find('.active').attr('for')
		
		# Close File
		closeFile: (fileId) ->
			# Fetch
			fileId or= @activeFile()

			# Elements
			$tab = @getTab fileId
			$panel = @getPanel fileId

			# Select Other
			$next = $tab.next()
			if $next.length is 0 then $next = $tab.prev()
			if $next.length isnt 0 then $next.trigger 'click'

			# Remove
			$tab.remove()
			$panel.remove()
			delete @editors[fileId]

		# Select File
		selectFile: (fileId) ->
			# Tab
			$tab = @getTab(fileId)
			$tab.addClass('active').siblings().removeClass 'active'

			# Panel
			$panel = @getPanel fileId
			if $panel.length isnt 0
				$panel.addClass('active').siblings().removeClass 'active'

		# Edit File
		editFile: (fileId) ->
			# Check
			if typeof @files.paths[fileId] is 'undefined'
				return
			
			# Fetch
			fileRelativePath = @getPath fileId

			# Add elements
			$tab = @getTab fileId
			if $tab.length is 0
				# Add tab
				$tab = $ '<li class="tab active" for="'+fileId+'">'+fileRelativePath+'</li>'
				@$mainTabs.append $tab

				# Add panel
				$panel = $ '<section for="'+fileId+'" class="panel active"><div class="editable"><pre class="ace"/></div></section>'
				$panel.find('.editable,.ace').height(@contentHeight).width(@contentWidth)
				@$mainPanels.append $panel

				# Initialise Ace
				editor = ace.edit $panel.find('.ace').get(0)

				# Customise Ace
				editor.setShowPrintMargin false
				mode = @extsToMode[fileId.replace(/.+\-([a-zA-Z0-9]+)$/,'$1')]
				if mode
					Mode = require('ace/mode/'+mode).Mode
					editor.getSession().setMode new Mode()
				
				# Save Editor
				@editors[fileId] = editor

				# Initialise NowPad
				nowpad.createInstance(
					element: editor
					documentId: fileId
				)

			else
				$panel = $('.panel[for=file-'+fileId+']')
			
			# Select
			$tab.trigger 'click'
	
	# Init
	filepad.init()

)(window)