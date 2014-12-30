require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
def absolute_paths(*paths)
  paths.collect {|rel| File.join(path_to_fixture('no_schema_bag'), rel)}
end
describe BagIt::Manifest do
  before(:all) do
    @name_parser = BagIt::NameParser.default('foo')
    @test = BagIt::Manifest.new(path_to_fixture('no_schema_bag/manifest-sha1.txt'), @name_parser)
    @all_entries = absolute_paths(
 'data/lol.wut',
 'data/lol.bar',
 'data/top/lol.wut',
 'data/top/foo.wut',
 'data/top/lol.bar'
     ).sort
  end
  it 'should load all the entries' do
    expected = @all_entries.sort
    actual = []
    @test.each_entry {|entry| actual << entry.path}
    expect(actual.sort).to eql(expected)
  end
  it 'should load a specific entry' do
    actual = []
    expected = absolute_paths('data/top/lol.wut')
    @test.each_entry('data/top/lol.wut') {|entry| actual << entry.path}
    expect(actual.sort).to eql(expected)
  end
  it 'should load entries matching a pattern' do
    actual = []
    expected = absolute_paths('data/lol.wut','data/top/lol.wut').sort
    @test.each_entry(/.*lol\.wut/) {|entry| actual << entry.path}
    expect(actual.sort).to eql(expected)
  end
end
