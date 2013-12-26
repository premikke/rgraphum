# -*- coding: utf-8 -*-

module Rgraphum
  module Importer
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Load graph from files
      #
      #
      def load(options={})
        build_options = options.dup
        build_options[:vertices] &&= open(build_options[:vertices])
        build_options[:edges]    &&= open(build_options[:edges])
        build_options[:path]     &&= open(build_options[:path])
        build_options[:options]  = options[:options]
        build build_options
      end

      # Parse str and load graph
      #
      # options[:options][:format] is source file format.
      # To build graph, method "build_graph_from_#{options[:options][:format]}" will be called.
      #
      def build(options={})
        graph = Rgraphum::Graph.new

        case options[:format]
        when :dump
          graph = load_from(options[:path])
        else
          build_method_name1 = "build_graph_from_#{options[:format]}".to_sym
          build_method_name2 = "build_#{options[:format]}".to_sym
          if respond_to?(build_method_name1, true)
            graph = send(build_method_name1, graph, options)
          elsif respond_to?(build_method_name2, true)
            graph = send(build_method_name2, graph, options)
          else
            raise ArgumentError, "Rgraphum::Importer::ClassMethods.build: Unknown format: '#{options[:format]}'"
          end
        end

        graph
      end

      private

      def build_graph_from_idg_json(graph, build_options={})
        vertices_json_str_or_stream = build_options[:vertices]
        edges_json_str_or_stream    = build_options[:edges]
        options = build_options[:options] || {}

        vertex_id_hash = {}
        community_hash = {}
        verbose = options[:verbose]

        puts "Loading vertices ... #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if verbose
        $stdout.flush if verbose
        if vertices_json_str_or_stream
          puts "JSON.load start  ... #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if verbose
          json = JSON.load(vertices_json_str_or_stream)
          puts "JSON.load end    ... #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if verbose
          json["result"].each_with_index do |vertex_hash, i|
            vertex_id_hash[vertex_hash["rid"]]  ||= vertex_id_hash.size
            community_hash[vertex_hash["c_id"]] ||= graph.communities.build
            params = {
              id:           vertex_id_hash[vertex_hash["rid"]],
              label:        vertex_hash["screen_name"],
              community_id: community_hash[vertex_hash["c_id"]].id,
            }
            graph.vertices.build(params)
            if verbose
              puts ".................... #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} #{i}" if (i % 10000) == 0
            end
          end
        end

        puts "Loading edges ...... #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if verbose
        $stdout.flush if verbose
        start_edge_number = (options[:start_edge_number].to_i rescue 1) || 1
        end_edge_number   = (options[:end_edge_number].to_i   rescue nil)
        end_edge_number   = nil if end_edge_number == 0
        if edges_json_str_or_stream
          json = JSON.load(edges_json_str_or_stream)
          json["result"].each_with_index do |edge_hash, i|
            next  if i < start_edge_number
            break if end_edge_number && end_edge_number < i
            params = {
              weight: edge_hash["weight"].to_f,
              source: vertex_id_hash[edge_hash["in"]],
              target: vertex_id_hash[edge_hash["out"]],
            }
            if graph.class::RGRAPHUM::Edge.has_field?(:created_at)
              params[:created_at] = Time.at(edge_hash["created_at"].to_i)
            end
            graph.edges.build(params)
          end
        end

        puts "Loaded!              #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if verbose
        $stdout.flush if verbose

        graph
      end
    end
  end
end
