// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:json_view/json_view.dart';
import 'package:provider/provider.dart';

import '../models/api_model.dart';
import '../models/conversations.dart';

class DebugPage extends StatelessWidget {
  const DebugPage();

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    var apiModel = Provider.of<ApiModel>(context);
    var request = apiModel.rawRequest;
    var response = apiModel.rawResponse;

    var responseAdditionalInfoParts = [
      if(apiModel.requestSecs > 0)
        '${apiModel.requestSecs.toStringAsFixed(1)}s',
      if(apiModel.tokensPerSecond > 0)
        '${apiModel.tokensPerSecond.toStringAsFixed(1)} tokens/s'
    ];

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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request JSON has been copied to the clipboard'))
                        );
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
                  if(responseAdditionalInfoParts.isNotEmpty)
                    Text(' (${responseAdditionalInfoParts.join('; ')})'),
                  if(response != null)
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: jsonEncode(response)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Response JSON has been copied to the clipboard'))
                        );
                      },
                      icon: const Icon(Icons.copy)
                    )
                ],
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
