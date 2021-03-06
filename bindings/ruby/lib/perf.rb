require "ffi"
require 'rbconfig'
require 'json'
require 'net/http'

module Perf
  extend FFI::Library

  module Utils

    def self.os
      @os ||= (
        host_os = RbConfig::CONFIG['host_os']
        case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /darwin|mac os/
          :macosx
        when /linux/
          :linux
        when /solaris|bsd/
          :unix
        else
          raise "unknown os: #{host_os.inspect}"
        end
      )
    end

    def self.path()
      base = File.dirname(__FILE__) + "/../../../build/lib/libperf"
      case os
        when :macosx
          return base + ".dylib"
        when :windows
          return base + ".dll"
        when :linux
          return base + ".so"
      end
    end
  end

  ffi_lib Utils.path()

  class LibIdentity < FFI::Struct
    layout :impl,  :pointer
  end

  class LibConfig < FFI::ManagedStruct
    layout :impl,  :pointer

    def self.release(ptr)
      self.perf_term_config(ptr)
    end
  end

  class LibContext < FFI::ManagedStruct
    layout :impl,  :pointer

    def self.release(ptr)
      self.perf_term_context(ptr)
    end
  end

  class LibMetaEvent < FFI::ManagedStruct
    layout :impl, :pointer

    def self.release(ptr)
      self.perf_term_meta_event(ptr)
    end
  end

  attach_function :perf_init_default_config, [ :string ], :pointer
  attach_function :perf_term_config, [ :pointer ], :void

  attach_function :perf_find_identity, [ :pointer ], :pointer
  attach_function :perf_identity_description, [ :pointer ], :string

  attach_function :perf_init_context, [ :pointer, :string ], :pointer
  attach_function :perf_term_context, [ :pointer ], :void

  attach_function :perf_init_meta_event, [ :pointer, :string ], :pointer
  attach_function :perf_term_meta_event, [ :pointer, :string ], :void

  attach_function :perf_init_event, [ :pointer ], :pointer
  attach_function :perf_term_event, [ :pointer ], :void

  attach_function :perf_dump_context, [ :pointer ], :string
  attach_function :perf_write_context, [ :pointer, :string ], :void

  class Identity
    def initialize(cfg)
      @ptr = LibIdentity.new(Perf.perf_find_identity(cfg.ptr))
    end

    def to_s
      return Perf.perf_identity_description(@ptr)
    end
  end

  class Config
    def initialize()
      @ptr = LibConfig.new(Perf.perf_init_default_config("ruby"))
    end

    attr_reader :ptr

    def identity
      return Identity.new(self)
    end
  end

  class Context
    def initialize(config, name)
      @ptr = LibContext.new(Perf.perf_init_context(config.ptr, name))
    end

    attr_reader :ptr

    def dump
      return Perf.perf_dump_context(@ptr)
    end

    def write(f)
      return Perf.perf_write_context(@ptr, f)
    end

    def create_meta_event(name)
      return MetaEvent.new(Perf.perf_init_meta_event(@ptr, name))
    end

    def block(name, &blk)
      ev = create_meta_event(name)

      ev.fire(&blk)
    end
  end

  class MetaEvent
    def initialize(ptr)
      @ptr = LibMetaEvent.new(ptr)
    end

    def fire()
      ev = Perf.perf_init_event(@ptr)
      yield
      Perf.perf_term_event(ev)
    end
  end

  class Package
    def initialize(vcs_branch, vcs_identity, vcs_description, files, recipe=nil, comment=nil)
      @contexts = Dir.glob(files).reduce({}) do |a, f|
        a[f] = JSON.parse(File.read(f))
        next a
      end

      @vcs = {
        :branch => vcs_branch,
        :identity => vcs_identity,
        :description => vcs_description
      }
      @recipe = recipe
      @comment = comment
    end

    def as_json()
      outputContexts = { }

      start = []
      @contexts.each do |file, json|
        name = json["name"]
        raise "invalid name passed" unless name.length > 0

        output = json.clone()
        output.delete("name")
        start << output["start"]
        outputContexts[name] = output
      end

      return {
        :vcs => @vcs,
        :start => start.min,
        :recipe => @recipe,
        :comment => @comment,
        :contexts => outputContexts
      }
    end

    def to_s()
      return JSON.generate(as_json())
    end

    def submit(addr)
      postData = Net::HTTP.post_form(URI.parse(addr), { "data" => to_s() })
    end
  end
end
