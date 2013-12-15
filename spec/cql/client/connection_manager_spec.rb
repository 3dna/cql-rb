# encoding: utf-8

require 'spec_helper'


module Cql
  module Client
    describe ConnectionManager do
      let :manager do
        described_class.new
      end

      let :connections do
        [double(:connection1), double(:connection2), double(:connection3)]
      end

      before do
        connections.each do |c|
          c.stub(:on_closed) do |&listener|
            c.stub(:closed_listener).and_return(listener)
          end
        end
      end

      describe '#add_connections' do
        it 'registers as a close listener on each connection' do
          manager.add_connections(connections)
          connections.each { |c| c.should have_received(:on_closed) }
        end

        it 'stops managing the connection when the connection closes' do
          manager.add_connections(connections)
          connections.each { |c| c.closed_listener.call }
          expect { manager.connection }.to raise_error(NotConnectedError)
        end
      end

      describe '#connected?' do
        it 'returns true when there are connections' do
          manager.add_connections(connections)
          manager.should be_connected
        end

        it 'returns false when there are no' do
          manager.should_not be_connected
        end
      end

      describe '#snapshot' do
        it 'returns a copy of the list of connections' do
          manager.add_connections(connections)
          s = manager.snapshot
          s.should == connections
          s.should_not equal(connections)
        end
      end

      describe '#connection' do
        before do
          connections.each { |c| c.stub(:on_closed) }
        end

        it 'raises a NotConnectedError when there are no connections' do
          expect { manager.connection }.to raise_error(NotConnectedError)
        end

        context 'when using the default strategy' do
          it 'returns one of the connections it is managing' do
            manager.add_connections(connections)
            connections.should include(manager.connection)
          end
        end

        context 'when using a custom strategy' do
          let :manager do
            described_class.new(strategy)
          end

          let :strategy do
            double(:strategy)
          end

          it 'asks the strategy which connection to use' do
            manager.add_connections(connections)
            strategy.stub(:select_connection).with(connections).and_return(connections[1])
            manager.connection.should == connections[1]
          end
        end
      end

      describe '#each_connection' do
        it 'yields each connection to the given block' do
          manager.add_connections(connections)
          yielded = []
          manager.each_connection { |c| yielded << c }
          yielded.should == connections
        end

        it 'is aliased as #each' do
          manager.add_connections(connections)
          yielded = []
          manager.each { |c| yielded << c }
          yielded.should == connections
        end

        it 'returns an Enumerable when no block is given' do
          manager.each.should be_an(Enumerable)
        end

        it 'raises a NotConnectedError when there are no connections' do
          expect { manager.each_connection { } }.to raise_error(NotConnectedError)
        end
      end

      context 'as an Enumerable' do
        before do
          connections.each_with_index { |c, i| c.stub(:index).and_return(i) }
        end

        it 'can be mapped' do
          manager.add_connections(connections)
          manager.map { |c| c.index }.should == [0, 1, 2]
        end

        it 'can be filtered' do
          manager.add_connections(connections)
          manager.select { |c| c.index % 2 == 0 }.should == [connections[0], connections[2]]
        end

        it 'raises a NotConnectedError when there are no connections' do
          expect { manager.select { } }.to raise_error(NotConnectedError)
        end
      end
    end
  end
end