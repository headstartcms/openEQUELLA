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

package com.tle.web.activation.section;

import com.tle.common.search.DefaultSearch;
import com.tle.web.activation.ActivationItemListEntry;
import com.tle.web.activation.ActivationSearch;
import com.tle.web.bulk.section.AbstractBulkSelectionSection;
import com.tle.web.search.base.AbstractFreetextResultsSection;
import com.tle.web.search.base.AbstractSearchResultsSection.SearchResultsModel;
import com.tle.web.search.event.FreetextSearchEvent;
import com.tle.web.search.event.FreetextSearchResultEvent;
import com.tle.web.sections.SectionInfo;
import com.tle.web.sections.SectionTree;
import com.tle.web.sections.equella.annotation.PlugKey;
import com.tle.web.sections.render.Label;
import java.util.List;
import javax.inject.Inject;

public class ActivationResultsSection
    extends AbstractFreetextResultsSection<ActivationItemListEntry, SearchResultsModel> {
  @Inject private ActivationItemList itemList;

  @PlugKey("results.title")
  private static Label LABEL_RESULTSTITLE;

  @Override
  protected Label getDefaultResultsTitle(
      SectionInfo info, FreetextSearchEvent searchEvent, FreetextSearchResultEvent resultsEvent) {
    return LABEL_RESULTSTITLE;
  }

  @Override
  protected DefaultSearch createDefaultSearch(SectionInfo info) {
    return new ActivationSearch();
  }

  @Override
  public ActivationItemList getItemList(SectionInfo info) {
    return itemList;
  }

  @Override
  protected void registerItemList(SectionTree tree, String id) {
    tree.registerInnerSection(itemList, id);
  }

  @Override
  protected void addAjaxUpdateDivs(SectionTree tree, List<String> ajaxList) {
    super.addAjaxUpdateDivs(tree, ajaxList);
    ajaxList.add(AbstractBulkSelectionSection.DIVID_SELECTBOX);
  }
}
