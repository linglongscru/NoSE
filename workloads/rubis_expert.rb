# rubocop:disable all

# Based on input from Catalin Avram <cavram@cs.uwaterloo.ca>

NoSE::Workload.new do
  Model 'rubis'

  # Define queries and their relative weights
  DefaultMix :browsing

  Group 'BrowseCategories', browsing: 4.44 + 3.21, bidding: 7.65 + 5.39 do
    Q 'SELECT users.nickname, users.password FROM users WHERE users.id = ?'
    # XXX Must have at least one equality predicate
    Q 'SELECT categories.id, categories.name FROM categories WHERE categories.dummy = 1'
  end

  Group 'ViewBidHistory', browsing: 2.38, bidding: 1.54 do
    Q 'SELECT items.name FROM items WHERE items.id = ?'
    Q 'SELECT user.nickname, bids.qty, bids.bid, items.max_bid, bids.date FROM items.bids.user WHERE items.id = ?'
  end

  Group 'ViewItem', browsing: 22.95, bidding: 14.17 do
    Q 'SELECT items.* FROM items WHERE items.id = ?'
  end

  Group 'SearchItemsByCategory', browsing: 27.77 + 8.26, bidding: 15.94 + 6.34 do
    Q 'SELECT items.id, items.name, items.initial_price, items.max_bid, items.nb_of_bids, items.end_date FROM items.category WHERE category.id = ? AND items.end_date >= ? LIMIT 25'
  end

  # XXX Not currently supported
  # # SearchItemsByRegion
  # # BrowseRegions

  Group 'ViewUserInfo', browsing: 4.41, bidding: 2.48 do
    Q 'SELECT users.* FROM users WHERE users.id=?'
    # XXX No received nickname
    Q 'SELECT comments_received.* FROM users.comments_received WHERE users.id = ?'
  end

  Group 'RegisterItem', bidding: 0.53 do
    Q 'INSERT INTO items SET id=?, name=?, description=?, initial_price=?, quantity=?, reserve_price=?, buy_now=?, nb_of_bids=0, max_bid=0, start_date=?, end_date=?'
    Q 'CONNECT items(?) TO category(?)'
    Q 'CONNECT items(?) TO seller(?)'
  end

  Group 'RegisterUser', bidding: 1.07 do
    Q 'INSERT INTO users SET id=?, firstname=?, lastname=?, nickname=?, password=?, email=?, rating=0, balance=0, creation_date=?'
    Q 'CONNECT users(?) TO region(?)'
  end

  Group 'StoreBid', bidding: 3.74 do
    Q 'INSERT INTO bids SET id=?, qty=?, bid=?, date=?'
    Q 'CONNECT bids(?) TO item(?)'
    Q 'CONNECT bids(?) TO user(?)'
    Q 'SELECT items.nb_of_bids, items.max_bid FROM items WHERE items.id=?'
    Q 'UPDATE items SET nb_of_bids=?, max_bid=? WHERE items.id=?'
  end

  Group 'StoreComment', bidding: 0.45 do
    Q 'SELECT users.rating FROM users WHERE users.id=?'
    Q 'UPDATE users SET rating=? WHERE users.id=?'
    Q 'INSERT INTO comments SET id=?, rating=?, date=?, comment=?'
    Q 'CONNECT comments(?) TO to_user(?)'
    # Q 'CONNECT comments(?) TO from_user(?)'
    Q 'CONNECT comments(?) TO item(?)'
  end
end

# rubocop:enable all