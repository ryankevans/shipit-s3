path = require 'path'
assert = require 'assert'
program = require 'commander'
moment = require 'moment'
_ = require 'lodash'
S3CLI = require './shipit-s3cli'

program
  .option('-r --release <TIMESTAMP>', 'release version timestamp')
  .parse(process.argv);

module.exports = (shipit) ->
  require('shipit-common')(shipit) # localQuiet

  s3cli = null
  version = null

  shipit.task('deploy:update',  ['deploy:s3:update'])
  shipit.task('deploy:publish', ['deploy:s3:publish'])
  shipit.task('deploy:clean',   ['deploy:s3:clean'])

  shipit.blTask 'rollback', ->
    shipit.start 's3:init', 'rollback:init'

  shipit.blTask 'rollback:init', ->
    if program.release
      version = program.release
      shipit.start 'deploy:s3:publish'
    else
      shipit.start 'rollback:ls'

  shipit.blTask 'rollback:ls', ->
    getReleases().then (releases) ->
      shipit.log _.concat('Past Releases:', releases).join('\n- ')


  shipit.on 'deploy', -> shipit.start 's3:init'

  shipit.blTask 'deploy:s3:clean', -> shipit.emit 'cleaned' # noop, keep all versions

  # -=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=-=-

  getReleases = ->
    shipit.localQuiet s3cli.ls(path.join(shipit.config.deployTo, 'v'))
    .then (response) ->
      json = JSON.parse(response.stdout.trim())
      dirs = _.map(json['CommonPrefixes'], 'Prefix')
      releases = _.map dirs, (path) -> path.match('^.*/v/(.*)/$')[1]
      releases = _.sortBy(releases)

  # -=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=--=-=-=-=-=-

  shipit.blTask 's3:init', ->
    assert !!shipit.config.aws?.profile, 'REQUIRED: config.aws.profile name'
    assert !!shipit.config.s3?.bucket, 'REQUIRED: config.s3.bucket'
    assert _.isEqual(shipit.config.servers, []), 'ERROR: config.servers must use [] placeholder'

    s3cli = new S3CLI(shipit.config.aws.profile, shipit.config.s3.bucket)
    version = moment().format('YYYY-MM-DD_HH-mm-ss')

    # standardize AWS S3 destination prefix/path
    shipit.config.deployTo = shipit.config.deployTo
      .replace(/^\/+/, '') # remove starting slash
      .replace(/\/+$/, '')  # remove trailing slash

  shipit.blTask 'deploy:s3:update', ->
    src = path.join(shipit.config.workspace, shipit.config.dirToCopy)
    dest = path.join(shipit.config.deployTo, 'v', version)
    shipit.local s3cli.cp(src, dest), cwd: shipit.config.workspace
    .then -> shipit.emit 'updated'

  shipit.blTask 'deploy:s3:publish', -> # activate the version
    dest = path.join(shipit.config.deployTo, 'REVISION')
    shipit.local s3cli.put(dest, version)
    .then -> shipit.emit 'published'

  shipit.on 'published', -> shipit.log "Release Published: #{version}"
