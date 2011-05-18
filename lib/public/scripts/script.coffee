((window)->
	# Globals
	$ = jQuery = window.jQuery
	console = window.console

	# Refresh File Tree
	refreshFileTree = (files) ->
		$tree = $ '<nav class="tree files" />'
		$files = $ '#files'

		$files.empty()
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
			
			return

		generateFiles files, $tree
		
		return

	# Refresh Files
	refreshFiles = (files) ->
		# Refresh file tree
		refreshFileTree files.tree

		# Ensure that any open documents actually still exist
		$main = $ '#main'
		$pads = $main.find '> .panels > .panel'
		$pads.each ->
			$pad = $ this
			id = $pad.attr('id')
			slug = id.replace(/^file\-/,'')
			if files.slugs[slug]
				# Keep
			else
				# Remove
				$pad.remove()
				$main.find('> .tabs > .tab[for='+id+']').remove()
	
	# Files
	$files = $('#files')
	$files.find('li.dir').live 'click', (event) ->
		$dir = $(this)
		event.stopPropagation()
		$dir.toggleClass('open')
	$files.find('li.file').live 'click', (event) ->
		$file = $(this)
		event.stopPropagation()

	# Tabs
	$('.tab').live 'click', (event) ->
		# Tab
		$tab = $(this).addClass 'active'
		$tab.siblings().removeClass 'active'
		# For
		$for = $('#' + $tab.attr('for'))
		if $for.length
			$for.addClass 'active'
			$for.siblings().removeClass 'active'
	
	# Initialise
	window.now.ready ->
		# Handshake
		window.now.handshake(
			# Notify List
			(err,files) ->
				if err
					throw err
				else if files
					refreshFiles files
			
			# Callback
			(err,files) ->
				if err
					throw err
				else if files
					refreshFiles files
		)


)(window)