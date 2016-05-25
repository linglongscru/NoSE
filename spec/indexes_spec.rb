module NoSE
  describe Index do
    include_context 'entities'

    let(:equality_query) do
      Query.new 'SELECT Tweet.Body FROM Tweet WHERE Tweet.TweetId = ?',
                workload.model
    end
    let(:combo_query) do
      Query.new 'SELECT Tweet.Body FROM Tweet WHERE Tweet.Timestamp > ? ' \
                'AND Tweet.TweetId = ?', workload.model
    end
    let(:order_query) do
      Query.new 'SELECT Tweet.Body FROM Tweet WHERE Tweet.TweetId = ? ' \
                'ORDER BY Tweet.Timestamp', workload.model
    end

    before(:each) do
      workload.add_statement equality_query
      workload.add_statement combo_query
      workload.add_statement order_query
    end

    it 'can return fields by field ID' do
      expect(index['Tweet_Body']).to eq(tweet['Body'])
    end

    it 'contains fields' do
      index = Index.new [tweet['TweetId']], [], [tweet['Body']],
                        [tweet.id_fields.first]
      expect(index.contains_field? tweet['TweetId']).to be true
    end

    it 'can store additional fields' do
      index = Index.new [tweet['TweetId']], [], [tweet['Body']],
                        [tweet.id_fields.first]
      expect(index.contains_field? tweet['Body']).to be true
    end

    it 'can calculate its size' do
      index = Index.new [tweet['TweetId']], [], [tweet['Body']],
                        [tweet.id_fields.first]
      entry_size = tweet['TweetId'].size + tweet['Body'].size
      expect(index.entry_size).to eq(entry_size)
      expect(index.size).to eq(entry_size * tweet.count)
    end

    context 'when materializing views' do
      it 'supports equality predicates' do
        index = equality_query.materialize_view
        expect(index.hash_fields).to eq([tweet['TweetId']].to_set)
      end

      it 'support range queries' do
        index = combo_query.materialize_view
        expect(index.order_fields).to eq([tweet['Timestamp']])
      end

      it 'supports multiple predicates' do
        index = combo_query.materialize_view
        expect(index.hash_fields).to eq([tweet['TweetId']].to_set)
        expect(index.order_fields).to eq([tweet['Timestamp']])
      end

      it 'supports order by' do
        index = order_query.materialize_view
        expect(index.order_fields).to eq([tweet['Timestamp']])
      end

      it 'keeps a static key' do
        index = combo_query.materialize_view
        expect(index.key).to eq 'i3932123199'
      end

      it 'includes only one entity in the hash fields' do
        query = Query.new 'SELECT Tweet.TweetId FROM Tweet.User ' \
                          'WHERE Tweet.Timestamp = ? AND User.City = ?',
                          workload.model
        index = query.materialize_view
        expect(index.hash_fields.map(&:parent).uniq).to have(1).item
      end
    end

    it 'can tell if it maps identities for a field' do
      index = Index.new [tweet['TweetId']], [], [tweet['Body']],
                        [tweet.id_fields.first]
      expect(index.identity_for? tweet).to be true
    end

    it 'can be created to map entity fields by id' do
      index = tweet.simple_index
      expect(index.hash_fields).to eq([tweet['TweetId']].to_set)
      expect(index.order_fields).to eq([])
      expect(index.extra).to eq([
        tweet['Body'],
        tweet['Timestamp'],
        tweet['Retweets']
      ].to_set)
      expect(index.key).to eq 'Tweet'
    end

    context 'when checking validity' do
      it 'cannot have empty hash fields' do
        expect do
          Index.new [], [], [tweet['TweetId']],
                    [tweet.id_fields.first]
        end.to raise_error InvalidIndexException
      end

      it 'cannot have hash fields involving multiple entities' do
        expect do
          Index.new [tweet['Body'], user['City']],
                    tweet.id_fields + user.id_fields, [],
                    [tweet.id_fields.first, tweet['User']]
        end.to raise_error InvalidIndexException
      end

      it 'must have fields at the start of the path' do
        expect do
          Index.new [tweet['TweetId']], [], [],
                    [tweet.id_fields.first, tweet['User']]
        end.to raise_error InvalidIndexException
      end

      it 'must have fields at the end of the path' do
        expect do
          Index.new [user['City']], [], [],
                    [tweet.id_fields.first, tweet['User']]
        end.to raise_error InvalidIndexException
      end
    end

    context 'when reducing to an ID path' do
      it 'moves non-ID fields to extra data' do
        index = Index.new [user['City']], [user['UserId']], [],
                          [user['UserId']]
        id_path = index.to_id_path

        expect(id_path.hash_fields).to match_array [user['UserId']]
        expect(id_path.order_fields).to be_empty
        expect(id_path.extra).to match_array [user['City']]
      end

      it 'does not change indexes which are already ID paths' do
        index = Index.new [user['UserId']], [tweet['TweetId']], [tweet['Body']],
                          [user['UserId'], user['Tweets']]
        id_path = index.to_id_path

        expect(id_path).to eq(index)
      end
    end
  end
end
