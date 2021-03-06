require 'support/test_classes'

RSpec.describe PerformLater::Aliasing do
  let(:klass) { DoWorkTester }
  let(:object){ klass.new }

  describe ".perform_later" do
    it "adds .do_work_later method" do
      expect(klass).to respond_to(:do_work_later)
    end

    it "aliases perform_async(:do_work, *params)" do
      expect(klass.method(:do_work_async)).to eq(klass.method(:do_work_later))
    end

    context "with the :as option" do
      context "using single method" do
        let(:klass){ DoWorkWithAsTester}

        it "adds method" do
          expect(klass).to respond_to(:entry_point_asynchronously)
        end
      end

      context "using array of methods" do
        let(:klass){ DoWorkWithArrayAsTester}

        it "adds first method" do
          expect(klass).to respond_to(:entry_point_asynchronously)
        end
        it "aliases rest of methods" do
          expect(klass.method(:entry_point_alias_asynchronously)).to eq(klass.method(:entry_point_asynchronously))
        end
      end
    end
  end

  describe ".do_work_later" do
    let(:params){ [:baz, :bat] }

    it "calls perform_async(:do_work, *params)" do
      expect(klass).to receive(:perform_async).with(:do_work, *params)
      klass.do_work_later(*params)
    end

    it "logs enqueueing as debug" do
      # run once to clear client logging
      klass.do_work_later(*params)
      expect(PerformLater.logger).to receive(:debug).with(a_kind_of(PerformLater::Messages::EnqueuedMessage))
      klass.do_work_later(*params)
    end

    it "logs enqueueing with correct attributes" do
      expect(PerformLater::Messages::EnqueuedMessage).to receive(:new).with(klass, :do_work, /[0-9a-f]*/)
      klass.do_work_later(*params)
    end

    context "when serialization hook exists" do
      let(:klass) do
        class DoWorkWithSerializationTester
          def self.serialize(a, b)
            [a.hash, b.hash]
          end
        end
        DoWorkWithSerializationTester
      end
      let(:serialized_params){ params.map(&:hash) }

      it "calls hook" do
        expect(klass).to receive(:serialize).with(*params)
        klass.do_work_later(*params)
      end

      it "passes serialized params to perform_async" do
        expect(klass).to receive(:perform_async).with(:do_work, *serialized_params)
        klass.do_work_later(*params)
      end
    end
  end

  describe ".perform_async" do
    it "stringifies method symbol through async bus" do
      method = :foo
      expect_any_instance_of(klass).to receive(:perform).with(method.to_s)
      klass.perform_async(method)
    end
  end
end