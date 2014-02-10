require_relative '../lib/indexes'
require_relative '../lib/parser'
require_relative '../lib/model'
require_relative '../lib/workload'

describe Index do
  before(:each) do
    @entity = Entity.new('Foo')
    @field = IDField.new('Id')
    @entity << @field
    @simple_query = Parser.parse('SELECT Id FROM Foo')
    @equality_query = Parser.parse('SELECT Id FROM Foo WHERE Foo.Id=3')
    @workload = Workload.new
    @workload.add_query @simple_query
    @workload.add_query @equality_query
    @workload.add_entity @entity
  end

  it 'has zero size when empty' do
    expect(Index.new([], []).fields.length).to eq(0)
    expect(Index.new([], []).entry_size).to eq(0)
    expect(Index.new([], []).size).to eq(0)
  end

  it 'contains fields' do
    index = Index.new([@field], [])
    expect(index.has_field? @field).to be_true
  end

  it 'can store additional fields' do
    index = Index.new([], [@field])
    expect(index.has_field? @field).to be_true
  end

  it 'can calculate its size' do
    index = Index.new([@field], [])
    @field *= 10
    expect(index.entry_size).to eq(@field.size)
    expect(index.size).to eq(@field.size * 10)
  end

  it 'does not support queries when empty' do
    index = Index.new([], [])
    expect(index.supports_query?(@simple_query, @workload)).to be_false
  end

  it 'supports equality queries on indexed fields' do
    index = Index.new([@field], [])
    expect(index.supports_query?(@equality_query, @workload)).to be_true
  end

  it 'does not support equality queries on unindexed fields' do
    index = Index.new([], [@field])
    expect(index.supports_query?(@equality_query, @workload)).to be_false
  end
end
