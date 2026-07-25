{
  services.home-assistant.config = {
    conversation.intents = {
      FindAndroid = [
        "(Find|Fight) my (phone|android|android phone)"
      ];
    };
    intent_script = {
      FindAndroid = {
        speech.text = "Send notification";
        action = {
          service = "notify.pushover";
          data = {
            message = "Phonefinderalert";
            target = "android";
            data.sound = "echo";
            data.priority = 1;
          };
        };
      };
    };

    "automation storage alerts" = [
      {
        id = "jeeves_storage_alert";
        alias = "Jeeves storage alert";
        mode = "queued";
        trigger = [
          {
            platform = "webhook";
            webhook_id = "b490d49b-e9d2-4a90-bbb1-4e9909507904";
            allowed_methods = [ "POST" ];
            local_only = true;
          }
        ];
        action = [
          {
            service = "notify.pushover";
            data = {
              title = "{{ trigger.json.title }}";
              message = "{{ trigger.json.message }}";
              target = "android";
              data = {
                sound = "siren";
                priority = 1;
              };
            };
          }
        ];
      }
    ];
  };
}
