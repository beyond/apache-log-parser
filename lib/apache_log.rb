# ApacheLog
require "active_support"
require "time"

module Apache
	LogFormats = {
		:combined => %r'^(.*?) (.*?) (.*) \[(.*?)\] "(.*?)(?:\s+(.*?)\s+(\S*?))?" (.*?) (.*?) "(.*?)" "(.*?)"(?: (.*))?$',
		:path => %r'^"(.*?)(?:\s+(.*?)\s+(\S*?))?"$',
		:time => %r"(\d+)\/([A-Z][a-z][a-z])\/(\d+):(\d+):(\d+):(\d+)( ([\+-])(\d\d)(\d\d))?"
	}

	module Log
		class Combined < Array
			attr_accessor :remote_ip, :ident, :user, :time, :path, :status, :size
			attr_accessor :method, :protocol, :referer, :agent, :appendix

			def initialize( args=nil )
				return unless args

				raise ArgumentError.new( "wrong number of arguments (#{args.size} for over 11)" ) if args.size < 11
				if args.last
					super
				else
					super args[0...-1]
				end

				@remote_ip, @ident, @user, timestr, 
						@method, @path, @protocol, @status, @size, @referer, @agent, @appendix = *args

				@ident = nil if @ident == "-"
				@user  = nil if @user == "-"
				@referer = nil if @referer == "-"
				@agen    = nil if @agent == "-"
				@status = @status == "-" ? nil : @status.to_i
				@size = @size == "-" ? nil : @size.to_i
			end

			def time
				unless @time
					t = self[3].dup
					t[11] = " "
					@time = Time.parse( t )
				end
				@time
			end

			class <<self
				def parse( line, delimiter = :space )
					if delimiter == :space
						m = LogFormats[:combined].match( line )
						if m
							Combined.new( m.to_a[ 1..-1 ] )
						else
							nil
						end
					elsif delimiter == :tab
						x = line.split( "\t", 10 )
						x[3] = x[3][1...-1]
						x[7] = x[7][1...-1]
						x[8] = x[8][1...-1]
						paths = LogFormats[ :path ].match( x[4] )
						x[4,1] = paths[ 1..-1 ]
						Combined.new( x )
					end
				end
			end

			def to_s( delimiter = :space )
				a = []
				a << ( remote_ip ? remote_ip : "-" )
				a << ( ident ? ident : "-" )
				a << ( user ? user : "-" )
				a << "[" + time.localtime.strftime( "%d/%b/%Y:%H:%M:%S %z" ) + "]"
				a << '"' + [ method ? method : "GET", path, protocol ].compact.join( " " ) + '"'
				a << ( status ? status : "-" )
				a << ( size ? size : "-" )
				a << '"' + ( referer ? referer : "-" ) + '"'
				a << '"' + ( agent ? agent : "-" ) + '"'
				a << @appendix if @appendix

				if delimiter == :space
					a.join( " " )
				else
					a.join( "\t" )
				end
			end
		end
	end

	class LogFile
		def open( *args, &block )
			a = LogFile.new( args )
			block.call( a ) if block
		end

		class <<self
			def read( *args )
				result = []
				foreach( *args ) { |x|
					result << x
				}
	
				result
			end

			def foreach( *args )
				options = args.extract_options!
				fname = args[0]
				delimiter = args[1] || :space
				format = options[ :format ] || :combined
				if format == :combined
					format = Apache::Log::Combined
				else
					raise ArgumentError.new( "Invalid log format" )
				end

				File.foreach( fname ) { |line|
					line.chomp!
					log = format.parse( line, delimiter )
					yield log if log
				}

				self
			end
		end

		def read
		end
	end
end
