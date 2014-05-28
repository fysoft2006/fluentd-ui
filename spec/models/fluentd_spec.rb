require 'spec_helper'

describe Fluentd do
  shared_examples_for "path permission" do |column|
    let(:path) { fluentd.send(column) }

    subject do
      fluentd.check_permission(column)
      fluentd.errors
    end

    context "file exists" do
      before { FileUtils.touch(path) }
      after { FileUtils.chmod(0755, path) }

      context "writable" do
        before { FileUtils.chmod(0600, path) }
        it { should be_blank }
      end

      context "not writable" do
        before { FileUtils.chmod(0400, path) }
        it { should_not be_blank }
        it { subject.get(column).should include(I18n.t('activerecord.errors.messages.lack_write_permission')) }
      end

      context "not readable" do
        before { FileUtils.chmod(0200, path) }
        it { should_not be_blank }
        it { subject.get(column).should include(I18n.t('activerecord.errors.messages.lack_read_permission')) }
      end

      context "is directory" do
        before { fluentd.send("#{column}=", Rails.root + "tmp") }
        it { should_not be_blank }
        it { subject.get(column).should include(I18n.t('activerecord.errors.messages.is_a_directory')) }
      end
    end

    context "file not exists" do
      let(:dir) { File.dirname(path) }
      before { FileUtils.rm path }
      after { FileUtils.chmod_R(0755, dir) }

      context "writable" do
        before { FileUtils.chmod(0700, dir) }
        it { should be_blank }
      end

      context "not writable" do
        before { FileUtils.chmod(0500, dir) }
        it { should_not be_blank }
        it { subject.get(column).should include(I18n.t('activerecord.errors.messages.lack_write_permission')) }
      end
    end
  end

  let(:fluentd) { build(:fluentd) }

  describe "#valid?" do
    before do
      %w(pid_file log_file config_file).each do |column|
        FileUtils.mkdir_p File.dirname(fluentd.send(column))
        FileUtils.touch fluentd.send(column)
      end
    end

    subject { fluentd }

    describe "variant" do
      before { fluentd.variant = variant }

      context "fluentd" do
        let(:variant) { "fluentd" }
        it { should be_valid }
      end

      context "foobar (not declared in Fluentd.variants)" do
        let(:variant) { "foobar" }
        it { should_not be_valid }
      end
    end

    describe "pid_file" do
      it_should_behave_like "path permission", :pid_file
    end

    describe "log_file" do
      it_should_behave_like "path permission", :log_file
    end

    describe "config_file" do
      it_should_behave_like "path permission", :config_file
    end
  end

  describe "variant" do
    before { fluentd.variant = variant }

    context "= fluentd" do
      let(:variant) { "fluentd" }
      it { fluentd.should be_fluentd }
      it { fluentd.should_not be_td_agent }
    end

    context "= td-agent" do
      let(:variant) { "td-agent" }
      it { fluentd.should_not be_fluentd }
      it { fluentd.should be_td_agent }
    end
  end

  describe "#agent" do
    before { fluentd.variant = variant }
    subject { fluentd.agent }

    context "fluentd" do
      let(:variant) { "fluentd" }
      it { should be_instance_of(Fluentd::Agent::Fluentd) }
    end

    context "td-agent" do
      let(:variant) { "td-agent" }
      it { should be_instance_of(Fluentd::Agent::TdAgent) }
    end
  end
end