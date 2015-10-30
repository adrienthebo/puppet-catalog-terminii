require 'puppet/indirector/catalog/compiler'
require 'puppet/util/lockfile'

# A catalog terminus that implements a buggy reader/writer lock.
class Puppet::Resource::Catalog::LockingCompiler < Puppet::Resource::Catalog::Compiler

  def find(request)
    attempt_readlock
    super
  ensure
    reader_lockfile.unlock
  end

  private

  def attempt_readlock
    spinlock(global_lockfile) do
      if writer_lockfile.locked?
        raise "Compiles are locked, try again later."
      else
        lock_or_explode(reader_lockfile)
        reader_lockfile.lock
      end
    end
  end

  def lockdir
    @lockdir ||= File.join(Puppet[:vardir], 'compiler-locks')
  end

  def global_lockfile
    @global_lockfile ||= Puppet::Util::Lockfile.new(File.join(lockdir, "global-lock"))
  end

  def writer_lockfile
    @writer_lockfile ||= Puppet::Util::Lockfile.new(File.join(lockdir, "writer-lock"))
  end

  def reader_lockfile
    @reader_lockfile ||= Puppet::Util::Lockfile.new(File.join(lockdir, "reader-#{rand(512)}-lock"))
  end

  def spinlock(lockfile, &block)
    loop { break if lockfile.lock }
    yield
  ensure
    lockfile.unlock
  end

  def lock_or_explode(lockfile)
    lockfile.lock or raise "HOLY EXPLETIVES WHY COULDN'T I ACQUIRE LOCKFILE #{lockfile.file_path}?"
  end
end
