path = require 'path'

class s3cli
  constructor: (@profile, @bucket) ->

  ls: (path) ->
    # path must not start or end with a /
    """ \
      aws --profile=#{@profile} \
        s3api list-objects --delimiter "/" \
        --bucket #{@bucket}  --prefix "#{path}/" \
    """

  cp: (src, dest) ->
    """ \
      aws --profile=#{@profile} \
        s3 cp --recursive --cache-control="max-age=31556926" \
        #{src} s3://#{path.join(@bucket, dest)} \
    """

  put: (fn, contents) ->
    """ \
      echo #{contents} | \
        aws --profile=#{@profile} s3 cp \
          --content-type text/plain --cache-control="max-age=0" \
          - \
          s3://#{path.join(@bucket, fn)} \
    """

module.exports = s3cli

