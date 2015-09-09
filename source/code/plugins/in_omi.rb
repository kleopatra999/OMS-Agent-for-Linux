#!/usr/local/bin/ruby


module Fluent


class OMIInput < Input
    Fluent::Plugin.register_input('omi', self)

    @omi_interface = nil

    def initialize
        super
        require_relative 'IN_OMI'
    end

    config_param :items, :array, :default => []
    config_param :run_interval, :time, :default => nil

    def configure (conf)
        super
    end

    def start
        @omi_interface = IN_OMI::OMIInterface.new
        @omi_interface.connect
        if @run_interval
            @finished = false
            @condition = ConditionVariable.new
            @mutex = Mutex.new
            @thread = Thread.new(&method(:run_periodic))
        else
            tag = "omi.data"
            time = Engine.now
            record = @omi_interface.enumerate(@items)
            router.emit(tag, time, record)
        end
    end

    def shutdown
        if @run_interval
            @mutex.synchronize {
                @finished = true
                @condition.signal
            }
            @thread.join
        end
        @omi_interface.disconnect
    end

    def run_periodic
        @mutex.lock
        done = @finished
        until done
            @condition.wait(@mutex, @run_interval)
            done = @finished
            @mutex.unlock
            if !done
                tag = "omi.data"
                time = Engine.now
                record = @omi_interface.enumerate(@items)
                router.emit(tag, time, record)
            end
            @mutex.lock
        end
        @mutex.unlock
    end

end # OMIInput


end # module