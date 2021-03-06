require File.expand_path('../spec_helper.rb', __FILE__)
require 'xcodeproj'

describe CocoaPodsAcknowledgements do

  UmbrellaTargetDescription = Pod::Installer::PostInstallHooksContext::UmbrellaTargetDescription

  before do
    @project_path = SpecHelper.temporary_directory + 'project.xcodeproj'
    @project = Xcodeproj::Project.new(@project_path)
    @project.initialize_from_scratch
    @sandbox = temporary_sandbox
    @spec1 = SpecHelper.spec1
    @spec2 = SpecHelper.spec2

    @settings_plist_content = {
      'Title' => 'Acknowledgements',
      'StringsTable' => 'Acknowledgements',
      'PreferenceSpecifiers' => [
        {
          'Title' => 'Acknowledgements',
          'Type' => 'PSGroupSpecifier',
          'FooterText' => 'This application makes use of the following third party libraries:'
        },
        {
          'Title' => 'monkeylib',
          'Type' => 'PSGroupSpecifier',
          'FooterText' => 'Permission is hereby granted ...'
        },
        {
          'Title' => 'BananaLib',
          'Type' => 'PSGroupSpecifier',
          'FooterText' => 'Permission is hereby granted ...'
        },
        {
          'Title' => nil,
          'Type' => 'PSGroupSpecifier',
          'FooterText' => 'Generated by CocoaPods - https://cocoapods.org'
        },
      ]
    }
    @plist_content = {
      "specs" => [
        {
          "name" => "monkeylib",
          "version"=> Pod::Version.new(1.0),
          "authors"=> {
            "CocoaPods" => "email@cocoapods.org"
          },
          "socialMediaURL" => "https://twitter.com/CocoaPods",
          "summary" => "A lib to do monkey things",
          "description" => "<h2>What is it</h2>\n\n<p>A lib to do monkey things</p>\n\n<h2>Why?</h2>\n\n<p>Why not?</p>\n",
          "licenseType" => "MIT",
          "licenseText" => "Permission is hereby granted ...",
          "homepage" => "https://github.com/CocoaPods/monkeylib"
        },
        {
          "name" => "BananaLib",
          "version" => Pod::Version.new(1.0),
          "authors" => {
            "Banana Corp" => nil,
            "Monkey Boy" => "monkey@banana-corp.local"
          },
          "socialMediaURL" => nil,
          "summary" => "Chunky bananas!",
          "description" => "<p>Full of chunky bananas.</p>\n",
          "licenseType" => "MIT",
          "licenseText" => "Permission is hereby granted ...",
          "homepage" => "http://banana-corp.local/banana-lib.html"
        }
      ]
    }

    @target = @project.new_target(:application, 'MyApp', :ios)
    @plist_path = @sandbox.root + 'Pods-MyApp-metadata.plist'
    @project.save
  end

  after do
    FileUtils.rm_rf(SpecHelper.temporary_directory)
  end

  describe 'In general' do
    it 'finds existing settings bundles' do
      settings_bundle = SpecHelper.temporary_directory + 'Settings.bundle'
      FileUtils.mkdir(settings_bundle)
      resource_group = @project.main_group.new_group('Resources')
      resource_group.new_file(settings_bundle)

      result = CocoaPodsAcknowledgements.settings_bundle_in_project(@project)
      result.to_s.should == settings_bundle.to_s
      FileUtils.rm_rf(settings_bundle)
    end
  end

  describe '#save_metadata' do
    it 'saves the metadata to disk' do
      Xcodeproj::Plist.expects(:write_to_path).with(@plist_content, @plist_path).once
      CocoaPodsAcknowledgements.save_metadata(@plist_content, @plist_path, @project, @sandbox, @target.uuid)
    end

    it 'adds the Pods group if not already existing' do
      @project.main_group["Pods"].should.be.nil?
      CocoaPodsAcknowledgements.save_metadata(@plist_content, @plist_path, @project, @sandbox, @target.uuid)
      @project.main_group["Pods"].should.not.be.nil?
    end

    it 'adds the plist to the Pods group' do
      CocoaPodsAcknowledgements.save_metadata(@plist_content, @plist_path, @project, @sandbox, @target.uuid)
      @project.main_group["Pods"].files.find { |f| f.path == 'Pods-MyApp-metadata.plist' }.should.not.be.nil?
    end

    it 'adds the plist to user target Copy Resources build phase' do
      CocoaPodsAcknowledgements.save_metadata(@plist_content, @plist_path, @project, @sandbox, @target.uuid)
      file_ref = @project.main_group["Pods"].files.find { |f| f.path == 'Pods-MyApp-metadata.plist' }
      file_ref.should.not.be.nil?

      @target.resources_build_phase.files.find { |f| f.file_ref == file_ref }.should.not.be.nil?
    end
  end

  describe 'plugin-hook' do
    before do
      @target_description = UmbrellaTargetDescription.new(@project, [@target], [@spec1, @spec2], :ios, '8.0', 'Pods-MyApp')
      @hook_context = Pod::Installer::PostInstallHooksContext.new(@sandbox, @sandbox.root, nil, [@target_description])
      Xcodeproj::Project.stubs(:open).returns(@project)
    end

    it 'generates acknowledgement plists' do
      CocoaPodsAcknowledgements.expects(:save_metadata).with(@plist_content, @plist_path, @project, @sandbox, @target.uuid)
      Pod::HooksManager.run(:post_install, @hook_context, { 'cocoapods-acknowledgements' => {}})
    end

    it 'generates a settings plist when specified' do
      settings_bundle = SpecHelper.temporary_directory + 'Settings.bundle'
      settings_plist_path = settings_bundle + 'Pods-MyApp-settings-metadata.plist'
      FileUtils.mkdir(settings_bundle)
      resource_group = @project.main_group.new_group('Resources')
      resource_group.new_file(settings_bundle)

      CocoaPodsAcknowledgements.expects(:save_metadata).with(@plist_content, @plist_path, @project, @sandbox, @target.uuid).once
      CocoaPodsAcknowledgements.expects(:save_metadata).with(@settings_plist_content, settings_plist_path.to_s, @project, @sandbox, @target.uuid).once
      Pod::HooksManager.run(:post_install, @hook_context, { 'cocoapods-acknowledgements' => { :settings_bundle => true }})
      FileUtils.rm_rf(settings_bundle)
    end
  end
end
