assert = require 'assert'
Path   = require 'path'
fs     = require 'fs'
R      = require 'reactive'

{ EventEmitter } = require 'events'

{ R, Project } = require "../#{process.env.JSLIB or 'lib'}/session"
TestVFS = require 'vfs-test'

DataDir = Path.join(__dirname, 'data')

readMementoSync = (name) -> JSON.parse(fs.readFileSync(Path.join(DataDir, name), 'utf8'))

class FakeSession
  constructor: ->
    @plugins = []
    @queue =
      register: ->
      add: ->
      once: ->
      after: (func) -> process.nextTick func

  after: (func) -> process.nextTick func

  findCompilerById: (compilerId) ->
    { id: compilerId }


describe "Project", ->

  it "should report basic info about itself", ->
    vfs = new TestVFS()
    session = new FakeSession()

    universe = new R.Universe()
    project = universe.create(Project, { session, vfs, path: "/foo/bar" })
    assert.equal project.name, 'bar'
    assert.equal project.path, '/foo/bar'
    assert.ok project.id =~ /^P\d+_bar$/


  it "should be able to load an empty memento", ->
    vfs = new TestVFS()
    session = new FakeSession()

    universe = new R.Universe()
    project = universe.create(Project, { session, vfs, path: "/foo/bar" })
    project.setMemento {}


  it "should be able to load a simple memento", ->
    vfs = new TestVFS()

    session = new FakeSession()

    universe = new R.Universe()
    project = universe.create(Project, { session, vfs, path: "/foo/bar" })
    project.setMemento { disableLiveRefresh: 1, compilationEnabled: 1 }


  it "should be able to load a real memento", ->
    vfs = new TestVFS()

    session = new FakeSession()

    universe = new R.Universe()
    project = universe.create(Project, { session, vfs, path: "/foo/bar" })
    project.setMemento readMementoSync('project_memento.json')

    assert.equal project.compilationEnabled, true
    assert.equal project.rubyVersionId, 'system'


  it "should save CSS files edited in Chrome Web Inspector", (done) ->
    vfs = new TestVFS()
    vfs.put '/foo/bar/app/static/test.css', "h1 { color: red }\n"

    session = new FakeSession()

    universe = new R.Universe()
    project = universe.create(Project, { session, vfs, path: "/foo/bar" })
    project.saveResourceFromWebInspector 'http://example.com/static/test.css', "h1 { color: green }\n", (err, saved) ->
      assert.ifError err
      assert.ok saved
      assert.equal vfs.get('/foo/bar/app/static/test.css'), "h1 { color: green }\n"

      done()


  it "should patch source SCSS/Stylus files when a compiled CSS is edited in Chrome Web Inspector", (done) ->
    styl1 = "h1\n  color red\n\nh2\n  color blue\n\nh3\n  color yellow\n"
    styl2 = styl1.replace 'blue', 'black'
    css1  = "/* line 1 : test.styl */\nh1 { color: red }\n/* line 4 : test.styl */\nh2 { color: blue }\n/* line 7 : test.styl */\nh3 { color: yellow }\n"
    css2  = css1.replace 'blue', 'black'

    vfs = new TestVFS()
    vfs.put '/foo/bar/app/static/test.styl', styl1
    vfs.put '/foo/bar/app/static/test.css', css1

    session = new FakeSession()

    universe = new R.Universe()
    project = universe.create(Project, { session, vfs, path: "/foo/bar" })
    project.saveResourceFromWebInspector 'http://example.com/static/test.css', css2, (err, saved) ->
      assert.ifError err
      assert.ok saved
      assert.equal vfs.get('/foo/bar/app/static/test.css'), css2
      assert.equal vfs.get('/foo/bar/app/static/test.styl'), styl2

      done()


  it "should be reactive", (done) ->
    universe = new R.Universe()
    vfs = new TestVFS()

    session = new FakeSession()

    project = universe.create(Project, { session, vfs, path: "/foo/bar" })

    universe.once 'change', -> done()
    project.setMemento { disableLiveRefresh: 1, compilationEnabled: 1 }


  describe "plugin support", ->

    it "should run plugin.loadProject on setMemento", ->
      vfs = new TestVFS()

      session = new FakeSession()
      session.plugins.push
        loadProject: (project, memento) ->
          project.foo = memento.bar

      universe = new R.Universe()
      project = universe.create(Project, { session, vfs, path: "/foo/bar" })
      project.setMemento { disableLiveRefresh: 1, bar: 42 }

      assert.equal project.foo, 42
