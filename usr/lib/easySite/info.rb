
# info class
# an info is an object similar to an XML-entity.
# Public fields are:
#   info.attributes - a hash containing name-strings and value-strings of the attributes
#   info.content - an array containing more info objects
#   info.path (read-only) (only available after initPaths on the root info)
# Private fields are:
#   info.type - the name
#   info.parent - the parent (only available after initPaths>
# an info-object is created in the source text by
# <type attr1=val1 attr2=val2> content </type>
# where 'type' is any string, or just by some random string, in which case
# the object will be of the type 'text'.
# 'text' Infos have no children.
class Info

	#_______________________
	# initialise
	# spc: info.new(strInfo, typeList)
	# pre: strInfo - source text
	#        typeList - |-separated list string of possible types. if empty, any type is parsed.
	# post: object tree created
	def initialize(strInfo,typeList)
	
		@parent = nil
		@prev = nil
		@next = nil
		@content = []
		
		# find next match
		if typeList.length == 0
			typeList = '\S+?'
		end
		expr = '\A\s*<\s*(' + typeList + ')((\s+.*?)|)>'
		expr = Regexp.new(expr, Regexp::MULTILINE)
		strInfo =~ expr
		if $& == nil
			@type = "text"
			@attributes = {}
			@content << strInfo
			return
		end
		strAttribs = String($~[2])
		@type = $~[1].delete('<>').strip
		strInfo.sub!($&,"")
		
		@attributes = {}
		if strAttribs.length > 0
			# attribute names
			names = []
			strAttribs = strAttribs.gsub(/\S*\s*=/) { |sub|
				# store without '=' and trailing white space
				names << sub.delete("=").gsub(/\s+\z/,"")
				"="
			}
			strAttribs = strAttribs + " ="

			# attribute values
			values = []
			i = 0
			strAttribs = strAttribs.scan(/[^=\s][^=]+=/) { |sub|
				# store without '=' and trailing white space
				values[i] = sub.delete("=").gsub(/\s+\z/,"").delete("\"")
				i += 1
			}

			# store names and values
			names.each_index { |i|
				@attributes[names[i]] = values[i]
			}
		end
		
		# find last closing tag
		found = false
		preMatch = ''
		strInfo.scan( Regexp::new('<\s*/\s*' + @type + ' *>') ) { |s|
			preMatch = $~.pre_match.strip
			found = true
		}
		
		if !found
			print "didn't find closing tag </" + @type + "> in " + strInfo + "\n"
		end

		# chop strContent into parts
		pieces = Info::chopString( preMatch, typeList )
				
		# recursion -> down the tree we go
		pieces.each { |str|
			@content << Info::new( str, typeList )
		}
	end

	#_______________________
	# chops the given string into smaller pieces, each defining an outer
	# Info entity
	def Info.chopString( strInfo, typeList )

		chops = [] # array of string parts
		tagDepth = 0 # the depth of tags
		strChops = '' # string accumulating current chop

		# follow the string and count the tag-level
		# if it changes between 0 and 1, chop the string
		tagXpr = Regexp::new('\A(.*?)(<\s*(/?)(' + typeList + ').*?>)', Regexp::MULTILINE)
		
		while strInfo =~ tagXpr # find next tag
		
			close = $~[3]
			if close.length == 0  # open: everything before the tag-expr. is the previous part
				tagDepth += 1
				if tagDepth == 1
					if $~[1].strip.length > 0
						chops << $~[1].strip
					end
					strChops = $~[2]
				else
					strChops += $&
				end
			else  # close: everything before, including the tag-expr., is prev. part
				tagDepth -= 1
				strChops += $&
				if tagDepth == 0
					if strChops.strip.length > 0
						chops << strChops.strip
						strChops = ''
					end
				end
			end
			strInfo = strInfo.sub( $&, '' )
		end
		if strInfo.strip.length
			chops << strInfo.strip
		end
		chops
	end

	#_______________________
	# get the name
	def type
		@type
	end

	#_______________________
	# get the content
	def content
		@content
	end

	#_______________________
	# get the path
	def path
		@path
	end

	#_______________________
	# get the attributes
	def attribs
		@attributes
	end

	#_______________________
	# set the attributes
	def setAttrib(name,value)
		@attributes[name] = value
	end

	#_______________________
	# convert to string
	def to_s
		str = "\n<" + @type
		@attributes.each{ |key,value|
			str += " " + key.to_s + " = " + value.to_s
		}
		if @type == 'text'
			str += "> " + @content[0] + " </" + @type + ">"
		else
			str += "> "
			@content.each { |c|
				str += c.to_s
			}
			str += "\n</" + @type + ">"
		end
		str
	end

	#_______________________
	# iterate over attributes
	# use as inf.eachAttrib { |name,value| ... }
	def eachAttrib
		@attributes.each{ |key,value|
			yield key,value
		}
	end

	#_______________________
	# traverse the tree, using depth search
	def map( &proc ) # this is a wrapper, which saves the given block
		traverse( proc )
	end
	def traverse( proc ) # this is the actual mapping fcn
		proc.call(self)
		if @type != 'text'
			@content.each{ |child|
				child.traverse( proc )
			}
		end
	end

	#_______________________
	# adjusts the path information of this node and all children
	# gets the own path as input (usually [])
	def initPaths( path )
		@path = Array::new(path) # ruby does assignments by reference
		if @type != 'text'
			@content.each_index { |i|
				if i-1 >= 0
					@content[i-1].next = @content[i]
				end
				if i+1 < @content.length
					@content[i+1].prev = @content[i]
				end
				@content[i].parent = self
				@content[i].initPaths( path.push(i) )
				path.pop
			}
		end
	end
	def prev=( p )
		@prev = p
	end
	def next=( n )
		@next = n
	end
	def parent=( p )
		@parent = p
	end;

	#_______________________
	# function parent, prev, next
	# for finding related nodes
	# on the same level
	# and one level up
	def prev
		@prev
	end
	def next
		@next
	end
	def up
		@parent
	end		
			
	#_______________________
	# get content by type
	# returns the first content with matching type
	def contentByType( type )
		content = nil
		@content.each_index { |i|
			if @content[i].type == type
				content = @content[i]
			end
		}
		content
	end

	#________________________
	# follows a given path
	# a path is an array of ints
	# call as
	# info.followPath(path) { |node| ... }
	def followPath( path, &proc )
		follow( path.reverse, proc )
	end
	def follow( path, proc )
		proc.call(self)
		if path.length > 0
			@content[ path.pop ].follow( path, proc )
		end
	end

	#________________________
	# gets info node from
	# a path, starting at this node
	# call as
	# info.child(path)
	def child( path )
		p = path.reverse
		n = p.pop
		if (n<0) | (n>content.length)
			nil
		elsif p.length == 0
			@content[ n ] 
		else
			@content[ n ].child( p.reverse )
		end;
	end
	
	#_________________________
	# gets next element on the
	# same level
	
	#_________________________
	# compare, >
	# a > b is true if a was defined after b in the
	# string (has parent nodes of larger index)
	def > (info)
		len = [ @path.length, info.path.length ].min
		if len > 0
			a = Array::new @path[0...len]
			b = Array::new info.path[0...len]
			i = 0
			until (i==len-1) || (a[i]!=b[i]); i += 1; end
			if i==len-1 && a[i]==b[i]
				return @path.length > info.path.length
			end
			a[i] > b[i]
		else @path.length > info.path.length
		end
	end

	#_________________________
	# compare, <
	# a < b is true if a was defined before b in the
	# string (has parent nodes of smaller index)
	def < (info)
		len = [ @path.length, info.path.length ].min
		if len > 0
			a = Array::new @path[0...len]
			b = Array::new info.path[0...len]
			i = 0
			until (i==len-1) || (a[i]!=b[i]); i += 1; end
			if i==len-1 && a[i]==b[i]
				return @path.length < info.path.length
			end
			a[i] < b[i]
		else @path.length < info.path.length
		end
	end

	#_________________________
	# compare, <=>
	# -1, if a < b
	# 1, if a > b
	# else 0
	# note that we haven't really defined an ==,
	# and I don't know if we should...
	def <=> (info)
		if self < info; return -1; end
		if self > info; return 1; end
		0
	end
end
