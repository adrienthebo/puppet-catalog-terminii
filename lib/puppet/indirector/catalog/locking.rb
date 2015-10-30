require 'puppet/indirector/catalog/compiler'
require 'puppet/util/lockfile'

# A catalog terminus that implements a buggy reader/writer lock.
#
# Reader algorithm:
#   1) Spinlock for the global lockfile
#   2) When the global lockfile is acquired, check for the writer lock.
#     2a) If the writer lock exists, log a warning, release the global lock, and abort
#     2b) If the writer doesn't exist, create a reader lock and release the global lock
#   3) Compile catalogs and whatnot
#   4) Release the reader lock.
#
# Writer algorithm (implemented in the writer code, not done here):
#   1) Spinlock for the global lockfile
#   2) When the global lockfile is acquired, create the writer lock and release the global lock
#   3) When all read locks have cleared, do writer things.
#   4) Release the writer lock.
#
# Notes:
#   - I haven't tested this.
#   - Filesystem locking makes people sad because it's horrid
#   - NFS + file locking = NOOOOPE
#   - It's possible that readers will try to lock the same lockfile; if that happens then the
#       reader that fails to get the lock will spuriously error.
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
