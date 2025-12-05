# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig'
  ignore_signature 'sig/test'

  check 'lib' # Directory name

  library 'bigdecimal'
  library 'digest'
  library 'logger'
  library 'openssl'
  library 'socket'
  library 'stringio'

  configure_code_diagnostics(D::Ruby.strict)
  configure_code_diagnostics do |hash|
    hash[D::Ruby::UnannotatedEmptyCollection] = :information
  end
end
