// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:json_view/json_view.dart';
import 'package:provider/provider.dart';

import '../models/api_model.dart';
import '../models/conversations.dart';
import '../util/popups.dart';

class DebugPage extends StatelessWidget {
  const DebugPage();

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    var apiModel = Provider.of<ApiModel>(context);
    var request = apiModel.rawRequest;
    var response = apiModel.rawResponse;

    var statLines = <String>[];
    for(var stats in apiModel.processingStatsArray) {
      var parts = <String>[];
      var promptSpeed = stats.promptProcessingSecs > 0 && stats.processedPromptTokensCount > 1
        ? '${(stats.processedPromptTokensCount / stats.promptProcessingSecs).toStringAsFixed(1)}t/s'
        : 'N/A';
      var tokensSpeed = stats.tokenGenerationSecs > 0 && stats.generatedTokensCount > 1
        ? '${(stats.generatedTokensCount / stats.tokenGenerationSecs).toStringAsFixed(1)}t/s'
        : 'N/A';
      if(apiModel.processingStatsArray.length > 1)
        parts.add('Index: ${stats.index}');
      parts.add('Total prompt tokens: ${stats.totalPromptTokensCount}');
      parts.add('Processed prompt tokens: ${stats.processedPromptTokensCount}');
      parts.add('Prompt processing time: ${stats.promptProcessingSecs.toStringAsFixed(1)}s');
      parts.add('Prompt processing speed: $promptSpeed');
      parts.add('Tokens generated: ${stats.generatedTokensCount}');
      parts.add('Token generation time: ${stats.tokenGenerationSecs.toStringAsFixed(1)}s');
      parts.add('Token generation speed: $tokensSpeed');
      var statLine = parts.join('\n');
      statLines.add(statLine);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(curConv?.name ?? '')
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Request',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  if(request != null)
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: jsonEncode(request)));
                        showPopupMsg(context, 'Request JSON has been copied to the clipboard');
                      },
                      icon: const Icon(Icons.copy)
                    )
                ],
              ),
              if(request != null)
                JsonView(
                  json: request,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics()
                )
              else
                const Text('N/A'),
              Row(
                children: [
                  const Text(
                    'Response',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  if(response != null)
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: jsonEncode(response)));
                        showPopupMsg(context, 'Response JSON has been copied to the clipboard');
                      },
                      icon: const Icon(Icons.copy)
                    )
                ],
              ),
              if(statLines.isNotEmpty)
                ExpandablePageView.builder(
                  itemCount: statLines.length,
                  itemBuilder: (context, index) {
                    var statLine = statLines[index];
                    return Card(
                      child: ListTile(
                        title: Text(statLine)
                      )
                    );
                  },
                ),
              if(response != null)
                JsonView(
                  json: response,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics()
                )
              else
                const Text('N/A'),
            ]
          )
        )
      )
    );
  }
}
