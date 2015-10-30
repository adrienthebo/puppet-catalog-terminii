require 'puppet/indirector/catalog/compiler'
require 'puppet/util/lockfile'

# A catalog terminus that implements a buggy reader/writer lock.
class Puppet::Resource::Catalog::LockingCompiler < Puppet::Resource::Catalog::Compiler

  def find(request)

    # To avoid a TOCTOU bug we always acquire a lockfile and then check for the global/write lock. If we
    # check for the global/write lock and then try to acquire a read lock, then we may add the read lock
    # after the write lock has been stamped down.
    #
    # This locking is incredibly crude and something I whipped up quickly; this could be done better.
    with_lock do
      if global_lockfile.locked?
        raise "Compiles are locked, try again later."
      end
      super
    end
  end

  private

  def lockdir
    @lockdir ||= File.join(Puppet[:vardir], 'compiler-locks')
  end

  def global_lockfile
    @lockfile ||= Puppet::Util::Lockfile.new(File.join(lockdir, "global-lock"))
  end

  def lockfile
    @lockfile ||= Puppet::Util::Lockfile.new(File.join(lockdir, rand(512)))
  end

  def with_lock(&block)
    lockfile.lock
    block.call
  ensure
    lockfile.unlock
  end
end
