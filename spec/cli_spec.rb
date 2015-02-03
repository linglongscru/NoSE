require 'graphviz'

module NoSE::CLI
  describe NoSECLI do
    it 'can output help text' do
      run_simple 'nose help'
      expect(all_output).to start_with 'Commands:'
      expect(last_exit_status).to eq 0
    end

    it 'can output a graph of a workload' do
      expect_any_instance_of(GraphViz).to \
        receive(:output).with(png: '/tmp/rubis.png')
      run_simple 'nose graph rubis /tmp/rubis.png'
    end
  end
end
