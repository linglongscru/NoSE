module Sadvisor
  describe 'Hotel example' do
    before(:each) do
      @w = w = Workload.new

      @w << Entity.new('POI') do
        ID 'POIID'
        String 'Name', 20
        String 'Description', 200
      end * 3_000

      @w << Entity.new('Hotel') do
        ID 'HotelID'
        String 'Name', 20
        String 'Phone', 10
        String 'Address', 50
        String 'City', 20
        String 'Zip', 5
      end * 1_000

      @w << Entity.new('HotelToPOI') do
        ID 'ID'
        ForeignKey 'HotelID', w['Hotel']
        ForeignKey 'POIID', w['POI']
      end * 5_000

      @w << Entity.new('Amenity') do
        ID 'AmenityID'
        String 'Name', 20
      end * 50

      @w << Entity.new('Room') do
        ID 'RoomID'
        ForeignKey 'HotelID', w['Hotel']
        String 'RoomNumber', 4
        Float 'Rate'
        ToManyKey 'Amenities', w['Amenity']
      end * 100_000

      @w << Entity.new('Guest') do
        ID 'GuestID'
        String 'Name', 20
        String 'Email', 20
      end * 50_000

      @w << Entity.new('Reservation') do
        ID 'ReservationID'
        ForeignKey 'GuestID', w['Guest']
        ForeignKey 'RoomID', w['Room']
        Date 'StartDate'
        Date 'EndDate'
      end * 250_000

      @query = Parser.parse 'SELECT Name FROM POI WHERE ' \
                            'POI.Hotel.Room.Reservation.' \
                            'Guest.GuestID = 3'
      @w.add_query @query
    end

    it 'can look up entities via multiple foreign keys' do
      guest_id = @w['Guest']['GuestID']
      index = Index.new([guest_id], [], [@w['POI']['Name']], [
        @w['Guest'], @w['Reservation'], @w['Room'], @w['Hotel'], @w['POI']
      ])
      planner = Planner.new @w, [index]
      tree = planner.find_plans_for_query @query
      expect(tree).to have(1).plan
      expect(tree).to include [IndexLookupStep.new(index)]
    end

    it 'uses the workload to find foreign key traversals' do
      fields = @w.find_field_keys %w(Hotel Room Reservation Guest GuestID)
      expect(fields).to eq \
          [[@w['Guest']['GuestID']],
           [@w['Reservation']['ReservationID']],
           [@w['Room']['RoomID']],
           [@w['Hotel']['HotelID']]]
    end

    it 'can look up entities using multiple indices' do
      simple_indexes = @w.entities.values.map(&:simple_index)
      planner = Planner.new @w, simple_indexes
      tree = planner.find_plans_for_query @query
      expect(tree).to include [
        IndexLookupStep.new(@w['Reservation'].simple_index),
        FilterStep.new([@w['Guest']['GuestID']], nil),
        IndexLookupStep.new(@w['Room'].simple_index),
        IndexLookupStep.new(@w['Hotel'].simple_index),
        IndexLookupStep.new(@w['POI'].simple_index)]
    end

    it 'can select from multiple plans' do
      indexes = @w.entities.values.map(&:simple_index)
      view = @query.materialize_view(@w)
      indexes << view

      planner = Planner.new @w, indexes
      tree = planner.find_plans_for_query @query
      expect(tree.size).to be > 1
      expect(tree.min).to match_array [IndexLookupStep.new(view)]
    end

    # XXX Disabled until fixed
    # it 'can search for an optimal index by checking non-overlapping indexes' do
    #   indexes = Search.new(@w).search_overlap 1000
    #   expect(indexes).to match_array [
    #     Index.new([@w['Guest']['GuestID']], [@w['POI']['Name']], [])
    #   ]
    # end
  end
end
