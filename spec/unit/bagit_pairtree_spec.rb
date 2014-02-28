# encoding: UTF-8
# these tests were copied from https://github.com/gsf/pairtree.js,
# which were in turn lifted from John Kunze in http://search.cpan.org/~jak/File-Pairtree-0.28/
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe BagIt::PairTree do

  def self.path_equals(label, expectation, *inputs)
    context label do
      let(:pairtree) { BagIt::PairTree }
      context "id to path" do
        subject {pairtree.path(*inputs)}
        it { should eq expectation }
      end
      context "path to id" do
        let(:pairtree) { BagIt::PairTree }
        subject {pairtree.id(*[expectation, inputs[1]].compact)}
        it { should eq inputs[0] }
      end
    end
  end

  path_equals('basic 3-char case', '/ab/c/', 'abc')
  path_equals('basic 4-char case', '/ab/cd/', 'abcd')
  path_equals('basic 7-char case', '/ab/cd/ef/g/', 'abcdefg')
  path_equals('5-char with \\ separator', '\\ab\\cd\\e\\', 'abcde', '\\')
  path_equals('2-char edge case', '/xy/', 'xy' )
  path_equals('1-char edge case', '/z/', 'z')
  path_equals('0-char edge case', '/', '')
  path_equals('7-char, empty separator case', '/ab/cd/ef/g/', 'abcdefg', '')
  path_equals('hyphen', '/12/-9/86/xy/4/', '12-986xy4')
  path_equals('long id with undescores', '/13/03/0_/45/xq/v_/79/38/42/49/5/', '13030_45xqv_793842495')
  path_equals('colons and slashes', '/ar/k+/=1/30/30/=x/t1/2t/3/', 'ark:/13030/xt12t3')
  path_equals('1-separator-char edge case', '/=/', '/')
  path_equals('a URL with colons, slashes, and periods', '/ht/tp/+=/=n/2t/,i/nf/o=/ur/n+/nb/n+/se/+k/b+/re/po/s-/1/','http://n2t.info/urn:nbn:se:kb:repos-1')
  path_equals('weird chars from spec example', '/wh/at/-t/he/-^/2a/@^/3f/#!/^5/e!/^3/f/', 'what-the-*@?#!^!?')
  path_equals('all weird visible chars', '/^5/c^/22/^2/a^/2b/^2/c^/3c/^3/d^/3e/^3/f^/5e/^7/c/',  '\\"*+,<=>?^|')
  path_equals('UTF-8 chars', '/An/n^/c3/^a/9e/s^/20/de/^2/0P/^c/3^/a8/le/ri/na/ge/',  'Années de Pèlerinage')
  path_equals('more crazy UTF-8 chars', '/^e/2^/82/^a/c^/c5/^b/dP/Z/', '€ŽPZ' )
end