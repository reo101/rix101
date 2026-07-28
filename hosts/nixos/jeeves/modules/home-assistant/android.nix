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
          action = "notify.send_message";
          target.entity_id = "notify.cheetah";
          data = {
            title = "Find Android";
            message = "Phonefinderalert";
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
            action = "notify.send_message";
            target.entity_id = "notify.cheetah";
            data = {
              title = "{{ trigger.json.title }}";
              message = "{{ trigger.json.message }}";
            };
          }
        ];
      }
    ];
  };
}
