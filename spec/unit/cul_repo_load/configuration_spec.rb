require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
describe Cul::Repo::Load::Configuration do
  let(:bag_path) { 'foo' }
  let(:checksum_alg) { 'lol' }
  let(:offset) { '42' }
  let(:config_hash) do
    # :bag_path, :checksum_alg, :pattern, :offset, :override
    {bag_path: bag_path, checksum_alg: checksum_alg, }
  end
  subject { Cul::Repo::Load::Configuration.new(config_hash) }
  it do
  end
  context "configured from environment" do
    let(:old_env) { Hash.new.merge! ENV }
    let(:test_env) do
      old_env.merge(
        'BAG_PATH' => bag_path,
        'CHECKSUM_ALG' => checksum_alg,
        'SKIP' => offset
      )
    end
    before do
      test_env.each do |k,v|
        ENV[k] = v
      end
    end
    after do
      test_env.each do |k,v|
        ENV[k] = nil
      end
      old_env.each do |k,v|
        ENV[k] = v
      end
    end
    subject { Cul::Repo::Load::Configuration.from_env }
    it do
      expect(subject.bag_path).to eql(bag_path)
      expect(subject.create_parent_works?).to be
      expect(subject.relationships).to be_empty
    end
    context "and configured from yml" do
      let(:test_env) do
        old_env.merge(
          'BAG_PATH' => bag_path,
          'CHECKSUM_ALG' => checksum_alg,
          'SKIP' => offset,
          'ORPHAN' => 'true',
          'LOAD_CONFIG' => path_to_fixture(File.join('load','config.yml'))
        )
      end
      it do
        expect(subject.bag_path).to eql('path/from/yml')
        expect(subject.create_parent_works?).not_to be
        expect(subject.relationships).to include(:cul_member_of)
        expect(subject.relationships[:cul_member_of]).to eql(['foo'])
        expect(subject.relationships[:publisher]).to eql(['lol','wut'])
      end
    end
  end
  context "configured from yml" do
    let(:config_path) {path_to_fixture(File.join('load','config.yml'))}
    subject { Cul::Repo::Load::Configuration.from_yml(config_path) }
    it do
      expect(subject.bag_path).to eql('path/from/yml')
      expect(subject.create_parent_works?).to be
    end
  end
end
