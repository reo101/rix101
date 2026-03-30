(local log (Log.open_topic "reo101-ee-echo-probe"))

(local desired-links
  [{:key "FL"
    :out-node "easyeffects_sink"
    :out-port "monitor_FL"
    :in-node "ee_sie_echo_canceller"
    :in-port "probe_FL"}
   {:key "FR"
    :out-node "easyeffects_sink"
    :out-port "monitor_FR"
    :in-node "ee_sie_echo_canceller"
    :in-port "probe_FR"}])

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
    [(make-node-interest "easyeffects_sink")
     (make-node-interest "ee_sie_echo_canceller")]))

(local ports-om
  (ObjectManager
    [(make-port-or-link-interest "port")]))

(local links-om
  (ObjectManager
    [(make-port-or-link-interest "link")]))

(local managed-links {})
(var reconcile-source nil)

(fn lookup-node  [name]
  (nodes-om:lookup
    [(make-global-constraint "node.name" name)]))

(fn lookup-port  [node name]
  (if (= node nil)
      nil
      (: node :lookup_port
        [(make-global-constraint "port.name" name)])))

(fn find-existing-link  [out-node-id out-port-id in-node-id in-port-id]
  (let [want {:link.output.node (tostring out-node-id)
              :link.output.port (tostring out-port-id)
              :link.input.node  (tostring in-node-id)
              :link.input.port  (tostring in-port-id)}]
    (var found nil)

    (each [link (links-om.iterate links-om)]
      (let [props link.properties]
        (when (and props
                   (= (. props "link.output.node") (. want "link.output.node"))
                   (= (. props "link.output.port") (. want "link.output.port"))
                   (= (. props "link.input.node")  (. want "link.input.node"))
                   (= (. props "link.input.port")  (. want "link.input.port")))
          (set found link))))

    found))

(var schedule-reconcile nil)
(fn ensure-link [spec]
  (let [key spec.key
        out-node (lookup-node spec.out-node)
        in-node  (lookup-node spec.in-node)
        out-port (lookup-port out-node spec.out-port)
        in-port  (lookup-port in-node  spec.in-port)]
    (when (and out-node in-node out-port in-port)
      (let [existing (find-existing-link
                       out-node.bound-id
                       out-port.bound-id
                       in-node.bound-id
                       in-port.bound-id)
            managed-link (. managed-links key)]
        (if (not= existing nil)
            (when (and (not= managed-link nil)
                       (not= managed-link existing))
              (tset managed-links key nil))
            (when (= managed-link nil)
              (let [link (Link "link-factory"
                           {:link.output.node out-node.bound-id
                            :link.output.port out-port.bound-id
                            :link.input.node  in-node.bound-id
                            :link.input.port  in-port.bound-id})]
                (tset managed-links key link)
                (link:connect
                  "pw-proxy-destroyed"
                  (fn []
                    (tset managed-links key nil)
                    (schedule-reconcile)))
                (link:activate
                  Features.ALL
                  (fn [_ err]
                    (when err
                      (tset managed-links key nil)
                      (: log :warning
                        (.. "failed to activate "
                            key
                            " monitor-to-probe link: "
                            (tostring err)))
                      (schedule-reconcile)))))))))))

(set schedule-reconcile
     #(if (not= reconcile-source nil)
          nil
          (set reconcile-source
            (Core.idle_add
              (fn []
                (set reconcile-source nil)

                (each [link (ipairs desired-links)]
                  (ensure-link link))

                false)))))

(nodes-om:connect "object-added" schedule-reconcile)
(nodes-om:connect "object-removed" schedule-reconcile)
(ports-om:connect "object-added" schedule-reconcile)
(ports-om:connect "object-removed" schedule-reconcile)
(links-om:connect "object-added" schedule-reconcile)
(links-om:connect "object-removed" schedule-reconcile)

(nodes-om:activate)
(ports-om:activate)
(links-om:activate)
(schedule-reconcile)
