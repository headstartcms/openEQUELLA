/*
 * Licensed to The Apereo Foundation under one or more contributor license
 * agreements. See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * The Apereo Foundation licenses this file to you under the Apache License,
 * Version 2.0, (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tle.web.searching.itemlist;

import com.google.inject.Inject;
import com.tle.beans.item.Item;
import com.tle.beans.item.attachments.AttachmentType;
import com.tle.beans.item.attachments.FileAttachment;
import com.tle.core.guice.Bind;
import com.tle.core.mimetypes.MimeTypeService;
import com.tle.web.itemlist.item.ListSettings;
import com.tle.web.itemlist.item.StandardItemListEntry;
import com.tle.web.sections.equella.annotation.PlugKey;
import com.tle.web.sections.events.RenderContext;
import com.tle.web.sections.result.util.CountLabel;
import com.tle.web.sections.result.util.IconLabel;
import com.tle.web.sections.result.util.IconLabel.Icon;
import com.tle.web.sections.result.util.PluralKeyLabel;
import com.tle.web.sections.standard.model.HtmlLinkState;
import com.tle.web.sections.standard.renderers.DivRenderer;
import com.tle.web.sections.standard.renderers.LinkRenderer;
import java.util.List;

@SuppressWarnings("nls")
@Bind
public class ItemListImageCountDisplaySection extends ItemListFileCountDisplaySection {
  @PlugKey("images.count")
  private static String COUNT_KEY;

  @Inject private MimeTypeService mimeTypeService;

  @Override
  public ProcessEntryCallback<Item, StandardItemListEntry> processEntries(
      final RenderContext context,
      List<StandardItemListEntry> entries,
      ListSettings<StandardItemListEntry> listSettings) {
    final boolean countDisabled = isFileCountDisabled();

    return new ProcessEntryCallback<Item, StandardItemListEntry>() {
      @Override
      public void processEntry(StandardItemListEntry entry) {
        if (!countDisabled) {
          final boolean canViewRestricted = canViewRestricted(entry.getItem());

          // Optimised?
          final List<FileAttachment> fileatts = entry.getAttachments().getList(AttachmentType.FILE);
          long count =
              fileatts.stream()
                  .filter(
                      fa -> {
                        if (canViewRestricted || !fa.isRestricted()) {
                          String mimeType =
                              mimeTypeService.getMimeTypeForFilename(fa.getFilename());
                          return mimeType.startsWith("image");
                        }
                        return false;
                      })
                  .count();

          if (count > 1) {
            // disabled link renders as a span, deel wiv it
            HtmlLinkState link =
                new HtmlLinkState(new IconLabel(Icon.IMAGE, new CountLabel(count), false));
            link.setDisabled(true);
            link.setTitle(new PluralKeyLabel(COUNT_KEY, count));
            entry.setThumbnailCount(new DivRenderer("filecount", new LinkRenderer(link)));
          }
        }
      }
    };
  }
}
