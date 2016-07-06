require 'yajl'
require 'fluent/input'
require 'fluent/event'
require 'fluent/config/error'
require 'fluent/parser'

module Fluent
  class SudoTail < Input
    Plugin.register_input('sudo_tail', self)

    def initialize
      super
      @command = nil
    end

    attr_accessor :command

    #The command (program) to execute.
    config_param :path, :string

    #The format used to map the program output to the incoming event.
    config_param :format, :string, default: 'none'

    #Tag of the event.
    config_param :tag, :string, default: nil

    #Fluentd will record the position it last read into this file.
    config_param :pos_file, :string, default: nil

    #The interval time between periodic program runs.
    config_param :run_interval, :time, default: nil

    #Start to read the log from the head of file.  
    config_param :read_from_head, :bool, default: false

    def configure(conf)
      super
      unless @path
        raise ConfigError, "'path' parameter is not set to a 'tail' source."
      end
      
      unless @pos_file
        raise ConfigError, "'pos_file' is required to keep track of file"
      end 

      unless @tag 
        raise ConfigError, "'tag' is required on sudo tail"
      end
      
      @parser = Plugin.new_parser(conf['format'])
      @parser.configure(conf)

      ruby = '/opt/microsoft/omsagent/ruby/bin/ruby '
      tailscript = '/opt/microsoft/omsagent/bin/tailfilereader.rb '
      @command = "sudo " << ruby << tailscript << @path <<  " -p #{@pos_file}" 
      
      if @read_from_head == 'true'
        @command += "--readfromhead"
      end       
    end

    def start
      #$log.info "Sudo tail command is #{@command}"
      if @run_interval
        @finished = false
        @thread = Thread.new(&method(:run_periodic))
      else
        @io = IO.popen(@command, 'r')
        @pid = @io.pid
        @thread = Thread.new(&method(:run))
      end
    end

    def shutdown
      if @run_interval
        @finished = true
        @thread.join
      else
        begin
          Process.kill(:TERM, @pid)
        rescue #Errno::ECHILD, Errno::ESRCH, Errno::EPERM
        end
        if @thread.join(60)  # TODO wait time
          return
        end

        begin
          Process.kill(:KILL, @pid)
        rescue #Errno::ECHILD, Errno::ESRCH, Errno::EPERM
        end
        @thread.join
      end
    end

    def run
      es = MultiEventStream.new
      @io.each { |line|
	 begin
          line.chomp!  # remove \n
          @parser.parse(line) { |time, record|
            if time && record
              es.add(time, record)
            else
              log.warn "pattern doesn't match: #{line.inspect}"
            end
            unless es.empty?
              tag=@tag
              begin
              router.emit(tag, time, line)
              rescue => e
              log.error "sudo_tail failed to emit", :error => e.to_s, :error_class => e.class.to_s, :tag => tag, :record => Yajl.dump(es)
              end
            end
          }
        rescue => e
          log.warn line.dump, error: e.to_s
          log.debug_backtrace(e.backtrace)
        end
      } 
    end

    def run_periodic
      until @finished
        begin
          sleep @run_interval
          @io = IO.popen(@command, "r")
          run
          Process.waitpid(@io.pid)
        rescue
          log.error "sudo_tail failed to run or shutdown child proces", error => $!.to_s, :error_class => $!.class.to_s
          log.warn_backtrace $!.backtrace
        end
      end
    end
  end

end

