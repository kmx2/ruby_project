
require "open3"
require "thread"


class AdbShell 
    attr_accessor :chkcount
    attr_writer :chkon, :chkstr   
    @chkstr=nil, @chkcount=0, @chkon=false  
 
  def initialize( adbname, adbpath="D:\\Phone\\adb-log\\")
    @adbname,@adbpath = adbname,adbpath
  end
  
  def openShell
    @stdin, @stdout, @stderr, @wait_thr=Open3.popen3( @adbpath+'adb shell')
 
    @exitAdb = false
      
    @qerr = Queue.new
    @errthd = Thread.new do
      Thread.current.abort_on_exception = true
      while ( !@exitAdb ) do
        line = @stderr.gets 
        @qerr.push(line)
      end
      @qerr.push :stderr_done
    end
  
    @qout = Queue.new
    @outthd = Thread.new do
      Thread.current.abort_on_exception = true
      while ( !@exitAdb ) do
        line = @stdout.gets 
        @qout.push(line)
      end
      @qout.push :stdout_done
    end

    
    @outProcThd = Thread.new do
      Thread.current.abort_on_exception = true
      while ( true ) do
        if ( stuff = @qout.pop )
          if @chkon
            if stuff.index( @chkstr )
              @chkcount+=1
            end
          end
              
          break if stuff == :stdout_done
        end
      end
    end
  
    @errProcThd = Thread.new do
      Thread.current.abort_on_exception = true
      while ( true ) do
        if ( emsg = @qerr.pop )
          puts emsg
          break if emsg == :stderr_done
        end
      end
    end
  end

  def runCmd( cmd, longcmd=false )
    @longcmd = longcmd
    @stdin.puts( cmd )
  end
  
  def closeShell
    if !@longcmd
      @stdin.puts('exit')
    else
      @stdin.puts('\x03')
    end
    @exitAdb=true
    
  end
  
end



logcmd='logcat -v time -b radio'
dialcmd='service call phone 2 s16 "13617311628"'
hangupcmd='input keyevent KEYCODE_ENDCALL'

gsmDialing='CLCC: 1,0,2'
gsmAlerting='CLCC: 1,0,3'
gsmCallingStatus=[ gsmDialing, gsmAlerting ]
 
logsh = AdbShell.new('log')
logsh.openShell
logsh.runCmd( logcmd,true )

dialsh = AdbShell.new('dial')
dialsh.openShell

logsh.chkstr=gsmCallingStatus[1]
logsh.chkcount=0
logsh.chkon=true

dialsh.runCmd( dialcmd )

while (1>logsh.chkcount ) do
end

dialsh.runCmd( hangupcmd )

logsh.chkon=false
puts logsh.chkcount
logsh.chkcount=0


#gets

logsh.closeShell
dialsh.closeShell



