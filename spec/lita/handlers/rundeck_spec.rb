require "spec_helper"

describe Lita::Handlers::Rundeck, lita_handler: true do

  let(:rundeck_noxml) do
    "This is not XML and should fail"
  end

  let(:rundeck_info) do
    File.read("spec/files/info.xml")
  end

  let(:rundeck_projects) do
    File.read("spec/files/projects.xml")
  end

  let(:rundeck_projects_empty) do
    File.read("spec/files/projects_empty.xml")
  end

  let(:rundeck_jobs) do
    File.read("spec/files/jobs.xml")
  end

  let(:rundeck_jobs_empty) do
    File.read("spec/files/jobs_empty.xml")
  end

  let(:rundeck_execution) do
    File.read("spec/files/execution.xml")
  end

  let(:rundeck_executions) do
    File.read("spec/files/executions.xml")
  end

  let(:rundeck_executions_empty) do
    File.read("spec/files/executions_empty.xml")
  end

  let(:rundeck_running) do
    File.read("spec/files/running.xml")
  end

  let(:rundeck_runnning_empty) do
    File.read("spec/files/running_empty.xml")
  end

  let(:rundeck_run) do
    File.read("spec/files/run.xml")
  end

  let(:rundeck_run_conflict) do
    File.read("spec/files/run_conflict.xml")
  end

  let(:rundeck_run_options_invalid) do
    File.read("spec/files/run_options_invalid.xml")
  end

  let(:rundeck_run_unauthorized) do
    File.read("spec/files/run_unauthorized.xml")
  end

  let(:rundeck_options) do
    File.read("spec/files/definition.xml")
  end

  let(:rundeck_output) do
    File.read("spec/files/output.xml")
  end

  let(:rundeck_output_limit_five) do
    File.read("spec/files/output_limit_five.xml")
  end

  let(:rundeck_output_empty) do
    File.read("spec/files/output_empty.xml")
  end

  let(:rundeck_output_exec_noexist) do
    File.read("spec/files/output_exec_noexist.xml")
  end


  let(:rundeck_output_notcomplete) do
    File.read("spec/files/output_notcomplete.xml")
  end

  it { routes_command("rundeck info").to(:info) }
  it { routes_command("rundeck projects").to(:projects) }
  it { routes_command("rundeck jobs").to(:jobs) }
  it { routes_command("rundeck executions").to(:executions) }
  it { routes_command("rundeck running").to(:running) }
  it { routes_command("rundeck aliases").to(:aliases) }
  it { routes_command("rundeck alias register aliasfoo --project Litatest --job dateoutput --options option=foobar").to(:alias_register) }
  it { routes_command("rundeck alias forget aliasfoo").to(:alias_forget) }
  it { routes_command("rundeck run aliasfoo").to(:run) }
  it { routes_command("rundeck run aliasfoo --options SECONDS=60").to(:run) }
  it { routes_command("rundeck run --project Litatest --job dateoutput").to(:run) }
  it { routes_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60").to(:run) }
  it { routes_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60 --report all").to(:run) }
  it { routes_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60 --report 5").to(:run) }
  it { routes_command("rundeck options aliasfoo").to(:options) }
  it { routes_command("rundeck options --project Litatest --job dateoutput").to(:options) }
  it { routes_command("rundeck output 285").to(:output) }
  it { routes_command("rundeck output 285 5").to(:output) }
  it { routes_command("rundeck output 6").to(:output) }
  it { routes_command("rundeck output 7").to(:output) }

  def grab_request(method, status, body)
    response = double('Faraday::Response', status: status, body: body)
    expect_any_instance_of(Faraday::Connection).to receive(method.to_sym).and_return(response)
  end

  before do
    Lita.config.handlers.rundeck.url = "https://rundeck.mycompany.org"
    Lita.config.handlers.rundeck.token = "abcdefghijzlmnopqrstuvwxyz"
    Lita.config.handlers.rundeck.api_debug = true
  end

  describe "#info" do
    it "returns nothing (but logs a message) if the API response is not XML" do
      grab_request("get", 200, rundeck_noxml)
      send_command("rundeck info")
      # @todo - I don't know rspec well enough to mock up the logger
      expect(replies.last).to be nil
    end

    it "replies with the rundeck server information with no users" do
      grab_request("get", 200, rundeck_info)
      send_command("rundeck info")
      expect(replies.last).to eq <<-EOF.chomp
System Stats for Rundeck 2.0.4 on node rundeck.mycompany.org
No users are currently allowed to execute jobs. Ask an admin to 'lita add CHAT_ID rundeck_users'
EOF
    end

    context "with users" do
      before do
        allow(Lita::Authorization).to receive(:groups_with_users).and_return(
          :rundeck_users => [ Lita::User.new(1, {"name"=>"Shell User"} ) ]
        )
      end

      it "replies with the rundeck server information with users" do
        grab_request("get", 200, rundeck_info)
        send_command("rundeck info")
        expect(replies.last).to eq <<-EOF.chomp
System Stats for Rundeck 2.0.4 on node rundeck.mycompany.org
Users allowed to execute jobs: Shell User
EOF
      end
    end
  end

  describe "#projects" do
    it "replies with the project list" do
      grab_request("get", 200, rundeck_projects)
      send_command("rundeck projects")
      expect(replies.last).to eq <<-EOF.chomp
[Litatest] - https://rundeck.mycompany.org/api/10/project/Litatest
EOF
    end

    it "replies emtpy project list" do
      grab_request("get", 200, rundeck_projects_empty)
      send_command("rundeck projects")
      expect(replies.last).to eq <<-EOF.chomp
No projects found
EOF
    end
  end

  describe "#jobs" do
    it "replies with the jobs list" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      send_command("rundeck jobs")
      expect(replies.last).to eq <<-EOF.chomp
[Litatest] - Foo:Bar;baz
aliasfoo = [Litatest] - dateoutput
[Litatest] - test2
EOF
    end

    it "replies with an empty jobs list" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs_empty)
      send_command("rundeck jobs")
      expect(replies.last).to eq <<-EOF.chomp
No jobs found
EOF
    end
  end

  describe "#executions" do
    it "replies with the executions list" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_executions)
      send_command("rundeck executions")
      expect(replies.last).to eq <<-EOF.chomp
254 succeeded Shell User [Litatest] dateoutput SECONDS:60 start:2014-08-10T06:19:22Z end:2014-08-10T06:20:23Z
255 succeeded Shell User [Litatest] dateoutput SECONDS:600 start:2014-08-10T06:20:33Z end:2014-08-10T06:30:36Z
256 succeeded Shell User [Litatest] dateoutput start:2014-08-10T18:21:41Z end:2014-08-10T18:21:41Z
257 succeeded Shell User [Litatest] dateoutput SECONDS:60 start:2014-08-10T21:31:29Z end:2014-08-10T21:32:30Z
258 succeeded Shell User [Litatest] dateoutput SECOND:600 start:2014-08-10T21:33:06Z end:2014-08-10T21:33:06Z
259 succeeded Shell User [Litatest] dateoutput SECONDS:600 start:2014-08-10T21:34:16Z end:2014-08-10T21:44:21Z
260 succeeded Shell User [Litatest] dateoutput start:2014-08-10T22:03:37Z end:2014-08-10T22:03:40Z
282 succeeded Shell User [Litatest] dateoutput SECONDS:60 start:2014-08-14T01:07:09Z end:2014-08-14T01:08:09Z
283 succeeded Shell User [Litatest] dateoutput SECONDS:5 start:2014-08-14T02:27:41Z end:2014-08-14T02:27:46Z
285 succeeded Shell User [Litatest] dateoutput SECONDS:600 start:2014-08-14T15:06:28Z end:2014-08-14T15:16:32Z
EOF
    end

    it "replies with the executions list limited to 2" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_executions)
      send_command("rundeck executions 2")
      expect(replies.last).to eq <<-EOF.chomp
283 succeeded Shell User [Litatest] dateoutput SECONDS:5 start:2014-08-14T02:27:41Z end:2014-08-14T02:27:46Z
285 succeeded Shell User [Litatest] dateoutput SECONDS:600 start:2014-08-14T15:06:28Z end:2014-08-14T15:16:32Z
EOF
    end

    it "replies with an empty executions list" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_executions_empty)
      send_command("rundeck executions")
      expect(replies.last).to eq <<-EOF.chomp
No executions found
EOF
    end
  end

  describe "#running" do
    it "replies with the running list" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_running)
      send_command("rundeck running")
      expect(replies.last).to eq <<-EOF.chomp
285 running Shell User [Litatest] dateoutput SECONDS:30 start:2014-08-14T15:06:28Z
EOF
    end

    it "replies with an empty running list" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_executions_empty)
      send_command("rundeck running")
      expect(replies.last).to eq <<-EOF.chomp
No executions found
EOF
    end
  end

  describe "#run" do
    it "submit job and be denied because of authorization" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(false)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60")
      expect(replies.last).to eq <<-EOF.chomp
You aren't authorized to run jobs
EOF
    end

    it "submit aliased job and have it succeed" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      send_command("rundeck run aliasfoo --options SECONDS=60")
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 is running. Average job duration is 1.717 seconds.
EOF
    end

    it "submit aliased job with options and have it succeed" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput --options foo=bar")
      send_command("rundeck run aliasfoo --options SECONDS=60")
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 is running. Average job duration is 1.717 seconds.
EOF
    end

    it "submit fully qualified job and have it succeed" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60")
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 is running. Average job duration is 1.717 seconds.
EOF
    end

    it "submit a fully qualified job and have it report back all the log" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      grab_request("get", 200, rundeck_execution)
      grab_request("get", 200, rundeck_output)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60 --report all")
      expect(replies.first).to eq <<-EOF.chomp
Execution 285 is running. Average job duration is 1.717 seconds.
EOF
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 output:
  23:16:30 Text of line 1
  23:16:31 Text of line 2
  23:16:32 Text of line 3
  23:16:33 Text of line 4
  23:16:34 Text of line 5
  23:16:35 Text of line 6
  23:16:36 Text of line 7
  23:16:37 Text of line 8
  23:16:38 Text of line 9
  23:16:39 Text of line 10
Execution 285 is complete (took 10.348s)
EOF
    end

    it "submit a fully qualified job and have it wait at least once, then report back all the log" do
      @time_now = Time.parse("2014-08-14T15:06:33Z")
      expect(Time).to receive(:now).and_return(@time_now)

      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      grab_request("get", 200, rundeck_running)
      grab_request("get", 200, rundeck_execution)
      grab_request("get", 200, rundeck_output)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60 --report all")
      expect(replies.first).to eq <<-EOF.chomp
Execution 285 is running. Average job duration is 1.717 seconds.
EOF
      expect(replies[1]).to eq <<-EOF.chomp
Execution 285 has been running for 5s (1s average)
EOF
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 output:
  23:16:30 Text of line 1
  23:16:31 Text of line 2
  23:16:32 Text of line 3
  23:16:33 Text of line 4
  23:16:34 Text of line 5
  23:16:35 Text of line 6
  23:16:36 Text of line 7
  23:16:37 Text of line 8
  23:16:38 Text of line 9
  23:16:39 Text of line 10
Execution 285 is complete (took 10.348s)
EOF
    end

    it "submit a fully qualified job and have it report back a limited log" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      grab_request("get", 200, rundeck_execution)
      grab_request("get", 200, rundeck_output_limit_five)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60 --report 5")
      expect(replies.first).to eq <<-EOF.chomp
Execution 285 is running. Average job duration is 1.717 seconds.
EOF
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 output:
  23:16:35 Text of line 6
  23:16:36 Text of line 7
  23:16:37 Text of line 8
  23:16:38 Text of line 9
  23:16:39 Text of line 10
Execution 285 is complete (took 10.348s)
EOF
    end

#     it "submit a fully qualified job and have it report back a limited log" do
#       allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
#       grab_request("get", 200, rundeck_projects)
#       grab_request("get", 200, rundeck_jobs)
#       grab_request("get", 200, rundeck_run)
#       grab_request("get", 200, rundeck_execution)
#       grab_request("get", 200, rundeck_output_limit_five)
#       send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60 --report 5")
#       expect(replies.first).to eq <<-EOF.chomp
# Execution 285 is running. Average job duration is 1.717 seconds.
# EOF
#       expect(replies.last).to eq <<-EOF.chomp
# Execution 285 output:
#   23:16:35 Text of line 6
#   23:16:36 Text of line 7
#   23:16:37 Text of line 8
#   23:16:38 Text of line 9
#   23:16:39 Text of line 10
# Execution 285 is complete (took 10.348s)
# EOF
#     end

    it "submit a non-existent job" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      send_command("rundeck run not-a-real-alias")
      expect(replies.last).to eq <<-EOF.chomp
Can't find an alias or project and job
EOF
    end

    it "submit a conflicting job" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run)
      grab_request("get", 200, rundeck_run_conflict)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60")
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=60")
      expect(replies.last).to eq <<-EOF.chomp
Job is already running and only allows one execution at a time
EOF
    end

    it "submit a job with bad options" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run_options_invalid)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=XXX")
      expect(replies.last).to eq <<-EOF.chomp
Job options were not valid: Option 'SECONDS' doesn't match regular expression \\d+, value: XXX
EOF
    end

    it "submit a job against a server missing the runAs permission" do
      allow(Lita::Authorization).to receive(:user_in_group?).and_return(true)
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_run_unauthorized)
      send_command("rundeck run --project Litatest --job dateoutput --options SECONDS=XXX")
      expect(replies.last).to eq <<-EOF.chomp
API token is unauthorized or lacks runAs permission; check the apitoken.aclpolicy
EOF
    end
  end

  describe "#aliases" do
    it "lists empty aliases list" do
      send_command("rundeck aliases")
      expect(replies.last).to eq <<-EOF.chomp
No aliases have been registered yet
EOF
    end

    it "lists aliases" do
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput --options foo=bar")
      send_command("rundeck aliases")
      expect(replies.last).to eq <<-EOF.chomp
Alias = [Project] - Job
 aliasfoo = [Litatest] - dateoutput - foo=bar - 
EOF
    end

  end

  describe "#alias_register" do
    it "registers a new alias" do
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      expect(replies.last).to eq <<-EOF.chomp
Alias registered
EOF
    end

    it "registers a new alias with options" do
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput --options foo=bar")
      expect(replies.last).to eq <<-EOF.chomp
Alias registered
EOF
    end

    it "fails to registers an existing alias" do
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      expect(replies.last).to eq <<-EOF.chomp
Alias already exists
EOF
    end

    it "fails on a bad format" do
      send_command("rundeck alias register aliasfoo")
      expect(replies.last).to eq <<-EOF.chomp
Format is bad, see help for more info
EOF
    end
  end

  describe "#alias_forget" do
    it "removes an alias" do
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      send_command("rundeck alias forget aliasfoo")
      expect(replies.last).to eq <<-EOF.chomp
Alias removed
EOF
    end

    it "fails to removes a non-existent alias" do
      send_command("rundeck alias forget not-a-real-alias")
      expect(replies.last).to eq <<-EOF.chomp
Alias not found
EOF
    end
  end

  describe "#options" do
    it "describe options of a job" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_options)
      send_command("rundeck options --project Litatest --job dateoutput")
      expect(replies.last).to eq <<-EOF.chomp
[Litatest] - dateoutput
  * SECONDS (REQUIRED) 
EOF
    end

    it "describe options of an aliased job" do
      grab_request("get", 200, rundeck_projects)
      grab_request("get", 200, rundeck_jobs)
      grab_request("get", 200, rundeck_options)
      send_command("rundeck alias register aliasfoo --project Litatest --job dateoutput")
      send_command("rundeck options aliasfoo")
      expect(replies.last).to eq <<-EOF.chomp
[Litatest] - dateoutput
  * SECONDS (REQUIRED) 
EOF
    end

    it "describe options of a non-existent job" do
      send_command("rundeck options aliasfoo")
      expect(replies.last).to eq <<-EOF.chomp
Can't find an alias or project and job
EOF
    end
  end

  describe "#output" do
    it "display output of an existing job with default number of lines" do
      grab_request("get", 200, rundeck_output)
      send_command("rundeck output 5")
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 output:
  23:16:30 Text of line 1
  23:16:31 Text of line 2
  23:16:32 Text of line 3
  23:16:33 Text of line 4
  23:16:34 Text of line 5
  23:16:35 Text of line 6
  23:16:36 Text of line 7
  23:16:37 Text of line 8
  23:16:38 Text of line 9
  23:16:39 Text of line 10
Execution 285 is complete (took 10.348s)
EOF
    end

    it "display output of an existing job with custom number of lines (5)" do
      grab_request("get", 200, rundeck_output_limit_five)
      send_command("rundeck output 285 5")
      expect(replies.last).to eq <<-EOF.chomp
Execution 285 output:
  23:16:35 Text of line 6
  23:16:36 Text of line 7
  23:16:37 Text of line 8
  23:16:38 Text of line 9
  23:16:39 Text of line 10
Execution 285 is complete (took 10.348s)
EOF
    end

    it "display output of an existing job that has no output" do
      grab_request("get", 200, rundeck_output_empty)
      send_command("rundeck output 6")
      expect(replies.last).to eq <<-EOF.chomp
Execution 6 output:
Execution 6 is complete (took 0.171s)
EOF
    end

    it "display output of an existing job that has no output" do
      grab_request("get", 200, rundeck_output_exec_noexist)
      send_command("rundeck output 7")
      expect(replies.last).to eq <<-EOF.chomp
Can't find execution for this command
EOF
    end

    it "display output of an existing job that hasn't completed with default number of lines" do
      grab_request("get", 200, rundeck_output_notcomplete)
      send_command("rundeck output 8")
      expect(replies.last).to eq <<-EOF.chomp
Execution 8 output:
  23:16:30 Text of line 1
  23:16:31 Text of line 2
  23:16:32 Text of line 3
Execution 8 is not complete (running 3.75s)
EOF
    end
  end
end
