(local log (Log.open_topic "reo101-ee-echo-probe"))

(local fallback-output-node "easyeffects_sink")
(local echo-canceller-node "ee_sie_echo_canceller")
(local settle-delay-ms 750)
(local retry-delay-ms 1000)
(var default-nodes-api nil)

(fn make-global-constraint [property value]
  (let [args [property "=" value]]
    (tset args :type "pw-global")
    (Constraint args)))

(fn make-node-interest [name]
  (let [args {:type "node"}]
    (table.insert args (make-global-constraint "node.name" name))
    (Interest args)))

(fn make-port-or-link-interest [kind]
  (Interest {:type kind}))

(local nodes-om
  (ObjectManager
    [(Interest {:type "node"})]))

(local ports-om
  (ObjectManager
    [(make-port-or-link-interest "port")]))

(local links-om
  (ObjectManager
    [(make-port-or-link-interest "link")]))

(local managed-links {})
(var last-output-node nil)
(var reconcile-source nil)

(fn lookup-node  [name]
  (nodes-om:lookup
    [(make-global-constraint "node.name" name)]))

(fn lookup-node-by-id [id]
  (var found nil)
  (each [node (nodes-om.iterate nodes-om)]
    (when (= (tostring node.bound-id)
             (tostring id))
      (set found node)))
  found)

(fn lookup-port  [node name]
  (if (= node nil)
      nil
      (: node :lookup_port
        [(make-global-constraint "port.name" name)])))

(fn get-default-output-node []
  (when (= default-nodes-api nil)
    (set default-nodes-api
      (Plugin.find "default-nodes-api")))

  (let [node-id (and default-nodes-api
                     (: default-nodes-api :call
                       "get-default-node"
                       "Audio/Sink"))]
    (or (lookup-node-by-id node-id)
        (lookup-node fallback-output-node))))

(fn port-sort-key [port]
  (let [props port.properties
        port-id (and props
                     (tonumber (. props "port.id")))]
    (or port-id
        port.bound-id
        0)))

(fn port-belongs-to-node? [port node]
  (let [props port.properties]
    (and props
         node
         (= (tostring node.bound-id)
            (tostring (. props "node.id"))))))

(fn monitor-port? [port]
  (let [props port.properties
        port-name (and props
                       (. props "port.name"))]
    (and props
         (= "out" (. props "port.direction"))
         (or (. props "port.monitor")
             (and port-name
                  (string.match port-name "^monitor_"))))))

(fn get-output-monitor-ports [node]
  (let [fl (lookup-port node "monitor_FL")
        fr (lookup-port node "monitor_FR")]
    (if (and fl fr)
        [fl fr]
        (let [ports []]
          (each [port (ports-om.iterate ports-om)]
            (when (and (port-belongs-to-node? port node)
                       (monitor-port? port))
              (table.insert ports port)))

          (table.sort ports
            (fn [a b]
              (< (port-sort-key a)
                 (port-sort-key b))))

          [(. ports 1) (. ports 2)]))))

(fn resolve-desired-links []
  (let [output-node (get-default-output-node)
        output-node-props (and output-node
                               output-node.properties)
        output-node-name (and output-node-props
                              (. output-node-props "node.name"))
        in-node (lookup-node echo-canceller-node)
        [left-monitor right-monitor] (get-output-monitor-ports output-node)
        probe-fl (lookup-port in-node "probe_FL")
        probe-fr (lookup-port in-node "probe_FR")]
    (when (not= output-node-name nil)
      (when (not= output-node-name last-output-node)
        (set last-output-node output-node-name)
        (: log :info
          (.. "using "
              output-node-name
              " as echo reference output"))))

    (when (and (= output-node-name nil)
               (not= last-output-node "<unresolved>"))
      (set last-output-node "<unresolved>")
      (: log :info
        "echo reference output is currently unresolved"))

    (if (and output-node
             in-node
             left-monitor
             right-monitor
             probe-fl
             probe-fr)
        [{:key "FL"
          :out-node output-node-name
          :out-node-id output-node.bound-id
          :out-port-id left-monitor.bound-id
          :in-node echo-canceller-node
          :in-node-id in-node.bound-id
          :in-port "probe_FL"
          :in-port-id probe-fl.bound-id}
         {:key "FR"
          :out-node output-node-name
          :out-node-id output-node.bound-id
          :out-port-id right-monitor.bound-id
          :in-node echo-canceller-node
          :in-node-id in-node.bound-id
          :in-port "probe_FR"
          :in-port-id probe-fr.bound-id}]
        [])))

(fn link-matches-spec? [link spec]
  (let [props link.properties]
    (and props
         (= (. props "link.output.node")
            (tostring spec.out-node-id))
         (= (. props "link.output.port")
            (tostring spec.out-port-id))
         (= (. props "link.input.node")
            (tostring spec.in-node-id))
         (= (. props "link.input.port")
            (tostring spec.in-port-id)))))

(fn links-to-input-port [in-port-id]
  (let [matching-links []]
    (each [link (links-om.iterate links-om)]
      (let [props link.properties]
        (when (and props
                   (= (. props "link.input.port")
                      (tostring in-port-id)))
          (table.insert matching-links link))))

    matching-links))

(fn destroy-link [key link reason]
  (when link
    (: log :info
      (.. "destroying "
          key
          " monitor-to-probe link: "
          reason))
    (pcall
      #(link:request_destroy))
    (when (= (. managed-links key) link)
      (tset managed-links key nil))))

(var schedule-reconcile nil)
(var ensure-link nil)
(fn reset-reconcile-source []
  (when (not= reconcile-source nil)
    (reconcile-source:destroy)
    (set reconcile-source nil)))

(fn queue-reconcile [delay-ms]
  (reset-reconcile-source)
  (set reconcile-source
    (Core.timeout_add
      delay-ms
      (fn []
        (set reconcile-source nil)

        (each [_ link (ipairs (resolve-desired-links))]
          (ensure-link link))

        false))))

(set ensure-link
  (fn [spec]
    (let [key spec.key]
      (var matching-link nil)
      (each [_ link (ipairs (links-to-input-port spec.in-port-id))]
        (if (link-matches-spec? link spec)
            (if (= matching-link nil)
                (set matching-link link)
                (destroy-link key link "duplicate desired link"))
            (destroy-link key link "stale echo reference")))

      (let [managed-link (. managed-links key)]
        (when (and managed-link
                   (not (link-matches-spec? managed-link spec)))
          (destroy-link key managed-link "managed link no longer matches selected output")))

      (when (= matching-link nil)
        (let [link (Link "link-factory"
                     {:link.output.node spec.out-node-id
                      :link.output.port spec.out-port-id
                      :link.input.node  spec.in-node-id
                      :link.input.port  spec.in-port-id})]
          (tset managed-links key link)
          (link:connect
            "pw-proxy-destroyed"
            (fn []
              (when (= (. managed-links key) link)
                (tset managed-links key nil))
              (schedule-reconcile retry-delay-ms)))
          (link:activate
            Features.ALL
            (fn [_ err]
              (when err
                (when (= (. managed-links key) link)
                  (tset managed-links key nil))
                (: log :warning
                  (.. "failed to activate "
                      key
                      " monitor-to-probe link: "
                      (tostring err)))
                (schedule-reconcile retry-delay-ms)))))))))

(set schedule-reconcile
     (fn [delay-ms]
       (queue-reconcile (or delay-ms settle-delay-ms))))

(nodes-om:connect "object-added" #(schedule-reconcile))
(nodes-om:connect "object-removed" #(schedule-reconcile))
(ports-om:connect "object-added" #(schedule-reconcile))
(ports-om:connect "object-removed" #(schedule-reconcile))
(links-om:connect "object-added" #(schedule-reconcile))
(links-om:connect "object-removed" #(schedule-reconcile))

(nodes-om:activate)
(ports-om:activate)
(links-om:activate)
(schedule-reconcile)
